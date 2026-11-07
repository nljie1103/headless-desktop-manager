#!/usr/bin/env python3
"""Manage the Linux RustDesk2.toml server settings safely.

`apply` operates on one explicit profile while RustDesk is stopped by the caller.
It preserves unrelated settings and verifies the updated TOML before an atomic
replace. The CLI never prints public keys or passwords.
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

SERVER_KEYS = ('id', 'relay', 'key')


def load(path):
    try:
        with Path(path).open('rb') as f:
            return tomllib.load(f)
    except (FileNotFoundError, PermissionError, ValueError, tomllib.TOMLDecodeError):
        return None


def fields(config):
    config = config or {}
    opts = config.get('options', {})
    if not isinstance(opts, dict):
        opts = {}
    ident = opts.get('custom-rendezvous-server') or config.get('rendezvous_server') or ''
    relay = opts.get('relay-server') or config.get('relay-server') or ''
    key = opts.get('key') or config.get('key') or ''
    return tuple(str(v) if isinstance(v, str) else '' for v in (ident, relay, key))


def draft(path):
    result = {}
    try:
        for line in Path(path).read_text(encoding='utf-8').splitlines():
            if '\t' not in line:
                continue
            k, v = line.split('\t', 1)
            if k in SERVER_KEYS and v and '\r' not in v:
                result[k] = v
    except (FileNotFoundError, PermissionError):
        pass
    return result


def render_updated(original, ident, relay, key):
    """Update only known root / [options] assignments, retaining all other keys."""
    if original.strip():
        tomllib.loads(original)  # Never corrupt a file we cannot safely interpret.
    if re.search(r'(?m)^\s*options\s*=', original):
        raise ValueError('inline [options] is not safe to modify automatically')
    updates = {
        'root': {'rendezvous_server': ident},
        'options': {'custom-rendezvous-server': ident,
                    'relay-server': relay, 'key': key},
    }
    sections_seen = set()
    seen = {'root': set(), 'options': set()}
    current = 'root'
    out = []
    section_pat = re.compile(r'^\s*\[([^\]]+)\]\s*(?:[#].*)?$')
    kv_pat = re.compile(r'^\s*([A-Za-z0-9_-]+)\s*=')

    def write_missing(section):
        if section in updates:
            for name, value in updates[section].items():
                if name not in seen[section]:
                    out.append(f'{name} = {json.dumps(value, ensure_ascii=True)}\n')
                    seen[section].add(name)

    for line in original.splitlines(keepends=True):
        m = section_pat.match(line.strip('\r\n'))
        if not m and re.match(r'^\s*\[\[.+\]\]\s*$', line):
            write_missing(current)
            current = 'other'
            out.append(line)
            continue
        if m:
            write_missing(current)
            current = m.group(1).strip()
            sections_seen.add(current)
            out.append(line)
            continue
        m = kv_pat.match(line)
        if m and current in updates and m.group(1) in updates[current]:
            name = m.group(1)
            if name not in seen[current]:
                out.append(f'{name} = {json.dumps(updates[current][name], ensure_ascii=True)}\n')
                seen[current].add(name)
            # Duplicate target settings are dropped. Other lines are untouched.
        else:
            out.append(line)
    if out and not out[-1].endswith('\n'):
        out[-1] += '\n'
    write_missing(current)
    if 'options' not in sections_seen:
        out.append('\n[options]\n')
        write_missing('options')
    result = ''.join(out)
    cfg = tomllib.loads(result)
    if fields(cfg) != (ident, relay, key) or cfg.get('rendezvous_server') != ident:
        raise ValueError('rendered settings do not match the requested server')
    return result


def patch_file(path, expected, uid, gid):
    target = Path(path)
    if not target.is_absolute():
        raise ValueError('a full config path is required')
    # Never follow symlinks in a path edited with root privilege.
    for p in (target, *target.parents):
        if p.is_symlink():
            raise ValueError('symlink in configuration path is not allowed')
    if target.exists() and not target.is_file():
        raise ValueError('configuration target is not a regular file')
    data = '' if not target.exists() else target.read_text(encoding='utf-8')
    rendered = render_updated(data, expected['id'], expected['relay'], expected['key'])
    parent = target.parent
    missing = []
    d = parent
    while not d.exists():
        missing.append(d)
        d = d.parent
    for d in reversed(missing):
        d.mkdir(mode=0o700)
        if uid or gid:
            os.chown(d, uid, gid)
    if parent.is_symlink():
        raise ValueError('configuration directory is a symlink')
    fd, temp = tempfile.mkstemp(prefix='.hdm-rustdesk-', dir=str(parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(rendered)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temp, stat.S_IRUSR | stat.S_IWUSR)
        s = os.stat(temp)
        if (s.st_uid, s.st_gid) != (uid, gid):
            os.chown(temp, uid, gid)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    if fields(load(path)) != (expected['id'], expected['relay'], expected['key']):
        raise ValueError('verification after write failed')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('inspect', 'get-id', 'get-relay', 'verify', 'validate', 'apply'))
    parser.add_argument('path')
    parser.add_argument('--draft')
    parser.add_argument('--uid', type=int)
    parser.add_argument('--gid', type=int)
    args = parser.parse_args()
    cfg = load(args.path)
    if args.action == 'apply':
        expected = draft(args.draft or '')
        if not all(expected.get(k) for k in SERVER_KEYS):
            print('草稿不完整，不能修改配置', file=sys.stderr)
            return 2
        if args.uid is None or args.gid is None or args.uid < 0 or args.gid < 0:
            print('未指定合法的文件所有者', file=sys.stderr)
            return 2
        try:
            patch_file(args.path, expected, args.uid, args.gid)
        except (OSError, UnicodeError, ValueError, tomllib.TOMLDecodeError) as ex:
            print('配置写入未通过验证：' + str(ex), file=sys.stderr)
            return 1
        print('配置已原子写入并校验文件内容；服务连接状态需另行验证')
        return 0
    if cfg is None:
        if args.action == 'inspect':
            print('配置文件：未找到或无法解析（不能确认保存或服务生效）')
        return 2
    ident, relay, key = fields(cfg)
    if args.action == 'inspect':
        print('配置文件：' + args.path)
        print('ID 服务器：' + (ident or '未找到'))
        print('中继服务器：' + (relay or '未找到'))
        print('服务器公钥：' + ('存在（内容不显示）' if key else '未找到'))
        print('提示：文件内容不能证明后台服务已加载或成功注册。')
    elif args.action == 'get-id':
        if not ident:
            return 2
        print(ident)
    elif args.action == 'get-relay':
        if not relay:
            return 2
        print(relay)
    elif args.action == 'validate':
        print('TOML 格式有效；ID：%s；Relay：%s；公钥：%s' % (bool(ident), bool(relay), bool(key)))
    elif args.action == 'verify':
        expected = draft(args.draft or '')
        if not all(expected.get(k) for k in SERVER_KEYS):
            return 2
        if (ident, relay, key) == (expected['id'], expected['relay'], expected['key']):
            print('此配置文件与草稿一致（服务是否采用该文件仍待验证）')
        else:
            print('此配置文件与草稿不一致', file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
