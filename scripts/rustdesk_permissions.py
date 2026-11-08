#!/usr/bin/env python3
"""Atomically patch documented RustDesk [options] permission keys.

Only file content is verified. Running RustDesk or a server-side policy may override
user settings; this tool deliberately does not claim effective remote authorization.
"""
import argparse
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import tomllib

FLAGS = ('enable-keyboard', 'enable-clipboard', 'enable-file-transfer',
         'enable-audio', 'enable-tunnel', 'enable-remote-restart',
         'enable-record-session')
EDITABLE_FLAGS = (*FLAGS, 'allow-remote-config-modification')
VALID_KEYS = {'access-mode', 'allow-remote-config-modification',
              'approve-mode', 'verification-method', *FLAGS}


def profile_settings(mode, remote='N'):
    if mode not in ('custom', 'full', 'view') or remote not in ('Y', 'N'):
        raise ValueError('invalid RustDesk permission mode')
    settings = {'access-mode': mode, 'allow-remote-config-modification': remote}
    if mode == 'custom':
        settings.update({flag: 'Y' for flag in FLAGS})
    return settings


def toggle_settings(flag: str, value: str):
    if flag not in EDITABLE_FLAGS or value not in ('Y', 'N'):
        raise ValueError('unsupported permission toggle')
    # Preserving all other flags avoids silently restoring privileges that
    # a user previously denied in custom mode.
    if flag == 'allow-remote-config-modification':
        return {flag: value}
    return {'access-mode': 'custom', flag: value}


def patch_options(original, settings):
    if not settings or any(k not in VALID_KEYS or not isinstance(v, str) for k, v in settings.items()):
        raise ValueError('unsupported RustDesk option')
    if original.strip():
        tomllib.loads(original)
    if re.search(r'(?m)^\s*options\s*=', original):
        raise ValueError('inline options cannot be safely patched')
    current = ''
    section_seen = False
    written = set()
    result = []
    sec = re.compile(r'^\s*\[([^\]]+)\]\s*(?:#.*)?$')
    kv = re.compile(r'^\s*([a-zA-Z0-9_-]+)\s*=')
    for line in original.splitlines(keepends=True):
        match = sec.match(line.strip('\r\n'))
        if match or re.match(r'^\s*\[\[.+\]\]\s*$', line):
            if current == 'options':
                result.extend(f'{key} = {json.dumps(value)}\n' for key, value in settings.items() if key not in written)
            current = match.group(1).strip() if match else ''
            section_seen |= current == 'options'
            result.append(line)
            continue
        match = kv.match(line)
        if current == 'options' and match and match.group(1) in settings:
            key = match.group(1)
            if key not in written:
                result.append(f'{key} = {json.dumps(settings[key])}\n')
                written.add(key)
        else:
            result.append(line)
    if result and not result[-1].endswith('\n'):
        result[-1] += '\n'
    if current == 'options':
        result.extend(f'{key} = {json.dumps(value)}\n' for key, value in settings.items() if key not in written)
    if not section_seen:
        result.append('\n[options]\n')
        result.extend(f'{key} = {json.dumps(value)}\n' for key, value in settings.items())
    rendered = ''.join(result)
    doc = tomllib.loads(rendered)
    if any(doc['options'].get(k) != v for k, v in settings.items()):
        raise ValueError('updated values not readable')
    return rendered


def update(path, settings, uid, gid):
    target = Path(path)
    if not target.is_absolute() or uid < 0 or gid < 0:
        raise ValueError('absolute path and valid file owner required')
    for part in (target, *target.parents):
        if part.is_symlink():
            raise ValueError('symlinks are not allowed')
    if target.exists() and not target.is_file():
        raise ValueError('configuration target is not a regular file')
    data = target.read_text('utf-8') if target.exists() else ''
    updated = patch_options(data, settings)
    dirs = []
    parent = target.parent
    while not parent.exists():
        dirs.append(parent)
        parent = parent.parent
    for folder in reversed(dirs):
        folder.mkdir(mode=0o700)
        os.chown(folder, uid, gid)
    fd, temp = tempfile.mkstemp(prefix='.hdm-permissions-', dir=str(target.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        os.chown(temp, uid, gid)
        os.chmod(temp, stat.S_IRUSR | stat.S_IWUSR)
        os.replace(temp, target)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    verify(path, settings)


def verify(path, settings):
    with Path(path).open('rb') as stream:
        doc = tomllib.load(stream)
    opts = doc.get('options', {})
    if not isinstance(opts, dict) or any(opts.get(k) != v for k, v in settings.items()):
        raise ValueError('permission settings did not match after readback')


def inspect(path):
    try:
        with Path(path).open('rb') as stream:
            data = tomllib.load(stream)
        options = data.get('options', {})
        if not isinstance(options, dict):
            options = {}
    except (OSError, tomllib.TOMLDecodeError):
        print('未找到可读取的配置文件：' + str(path))
        return 2
    print('配置路径：' + str(path))
    for key in ('access-mode', *FLAGS, 'allow-remote-config-modification', 'approve-mode', 'verification-method'):
        print(f'  {key}: {options.get(key, "未设置（按 RustDesk 默认值）")}')
    print('仅验证本地配置；RustDesk 服务是否采用及高级策略是否覆盖，需实际连接验证。')
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('inspect', 'apply', 'verify'))
    parser.add_argument('path')
    parser.add_argument('--mode', choices=('custom', 'full', 'view', 'auth', 'toggle'), default='custom')
    parser.add_argument('--remote', choices=('Y', 'N'), default='N')
    parser.add_argument('--flag', choices=EDITABLE_FLAGS)
    parser.add_argument('--value', choices=('Y', 'N'))
    parser.add_argument('--uid', type=int, default=-1)
    parser.add_argument('--gid', type=int, default=-1)
    args = parser.parse_args()
    if args.action == 'inspect':
        return inspect(args.path)
    try:
        settings = (toggle_settings(args.flag, args.value) if args.mode == 'toggle'
                    else {'approve-mode': 'password', 'verification-method': 'use-permanent-password'}
                    if args.mode == 'auth' else profile_settings(args.mode, args.remote))
    except ValueError as error:
        print('RustDesk 权限配置失败：' + str(error), file=sys.stderr)
        return 1
    try:
        if args.action == 'apply':
            update(args.path, settings, args.uid, args.gid)
        else:
            verify(args.path, settings)
    except (OSError, ValueError, UnicodeError, tomllib.TOMLDecodeError) as error:
        print('RustDesk 权限配置失败：' + str(error), file=sys.stderr)
        return 1
    print('配置文件内容校验通过；远端真实权限仍需验证。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
