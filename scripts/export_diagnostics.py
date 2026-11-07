#!/usr/bin/env python3
"""Export captured HDM/apt/GDM/RustDesk evidence into a root-owned archive.

This tool cannot recover events from before logging was enabled. The output is
best-effort redacted; users should inspect it before sharing outside their VM.
"""
import argparse
import datetime as dt
import io
import gzip
import os
import pathlib
import re
import subprocess
import tarfile

MAX_ONE = 16 * 1024 * 1024
MAX_TOTAL = 72 * 1024 * 1024
REDACTIONS = [
    (re.compile(r'(?i)(\b(?:password|passwd|token|secret|api[_-]?key|authorization|private[_-]?key)\b\s*(?:=|:|\s)\s*)[^\s,;]+'), r'\1[REDACTED]'),
    (re.compile(r'(?i)(\b(?:server[_-]?key|公钥|密钥)\b\s*(?:=|:|：)\s*)[A-Za-z0-9+/_=-]{18,}'), r'\1[REDACTED]'),
    (re.compile(r'(?i)(--password\s+)[^\s]+'), r'\1[REDACTED]'),
    (re.compile(r'(?i)(Authorization:\s*(?:Bearer|Basic)\s+)[^\s]+'), r'\1[REDACTED]'),
]

def clean(buf):
    text = buf.decode('utf-8', 'replace')
    for regex, new in REDACTIONS:
        text = regex.sub(new, text)
    return text.encode('utf-8')


def command(*args):
    try:
        r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=18, check=False)
        return r.stdout[:MAX_ONE] + (b'\n[output truncated]\n' if len(r.stdout) > MAX_ONE else b'')
    except (OSError, subprocess.TimeoutExpired) as exc:
        return ('Command unavailable or timed out: %s\n' % type(exc).__name__).encode()


def collect(outdir, logdir):
    outdir = pathlib.Path(outdir)
    outdir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(outdir, 0o700)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    outfile = outdir / ('hdm-diagnostics-' + stamp + '-' + str(os.getpid()) + '.tar.gz')
    written = 0
    omitted = []
    def add(tar, name, data):
        nonlocal written
        if written >= MAX_TOTAL:
            omitted.append(name + ': total size cap')
            return
        if len(data) > MAX_ONE:
            data = data[-MAX_ONE:]
            data = b'[first part truncated due to size cap]\n' + data
            omitted.append(name + ': oldest part truncated')
        data = clean(data)
        written += len(data)
        meta = tarfile.TarInfo(name)
        meta.size = len(data)
        meta.mode = 0o600
        tar.addfile(meta, io.BytesIO(data))
    fd = os.open(outfile, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        with tarfile.open(fileobj=stream, mode='w:gz') as tar:
            add(tar, 'README.txt', '''HDM diagnostic export (sensitive data redacted on best-effort basis).
Includes captured install steps and actual system state; it does NOT prove remote screen capture works.
Review contents before uploading to a third-party AI. Logs may still contain hostnames, IPs, or identifying metadata.
The archive cannot reconstruct historical commands that HDM did not log.
'''.encode())
            candidates = [pathlib.Path('/etc/os-release')]
            for pattern in ('/var/log/apt/history.log*', '/var/log/apt/term.log*', '/var/log/dpkg.log*'):
                candidates += sorted(pathlib.Path('/').glob(pattern.lstrip('/')))[:16]
            for path in candidates:
                if not path.is_file() or path.is_symlink(): continue
                try:
                    if path.suffix == '.gz':
                        with gzip.open(path, 'rb') as source:
                            raw = source.read(MAX_ONE + 1)
                    else:
                        with path.open('rb') as source:
                            raw = source.read(MAX_ONE + 1)
                    name = path.as_posix().lstrip('/')
                    add(tar, 'system/' + name.removesuffix('.gz'), raw)
                except (OSError, EOFError): omitted.append(str(path) + ': unreadable')
            base = pathlib.Path(logdir)
            if base.is_dir() and not base.is_symlink():
                for path in sorted(base.glob('*.log'))[:2000]:
                    if not path.is_file() or path.is_symlink(): continue
                    try: add(tar, 'hdm/' + path.name, path.read_bytes())
                    except OSError: omitted.append(str(path) + ': unreadable')
            cmds = [
                ('overview/kernel.txt', ['uname', '-a']),
                ('overview/disk.txt', ['df', '-h', '/']),
                ('overview/memory.txt', ['free', '-h']),
                ('overview/systemd-target.txt', ['systemctl', 'get-default']),
                ('overview/services.txt', ['systemctl', 'status', 'gdm3', 'rustdesk', 'display-manager', 'hdm-xvfb', '--no-pager', '--lines=50']),
                ('overview/failed-services.txt', ['systemctl', '--failed', '--no-pager']),
                ('overview/sessions.txt', ['loginctl', 'list-sessions', '--no-pager']),
                ('overview/drm.txt', ['ls', '-l', '/sys/class/drm']),
                ('journal/gdm3.txt', ['journalctl', '-b', '-u', 'gdm3', '-u', 'display-manager', '--no-pager', '-n', '1800']),
                ('journal/rustdesk.txt', ['journalctl', '-b', '-u', 'rustdesk', '--no-pager', '-n', '1800']),
                ('journal/display.txt', ['journalctl', '-b', '-u', 'hdm-xvfb', '--no-pager', '-n', '500']),
                ('journal/boot-errors.txt', ['journalctl', '-b', '-p', 'err', '--no-pager', '-n', '900']),
                ('packages/rustdesk.txt', ['dpkg-query', '-W', 'rustdesk', 'libva-x11-2', 'libxdo3']),
                ('packages/desktop.txt', ['dpkg-query', '-W', 'gnome-shell', 'gdm3', 'ubuntu-desktop', 'pipewire', 'xdg-desktop-portal']),
            ]
            for name, cmd in cmds:
                add(tar, name, command(*cmd))
            add(tar, 'export/omissions.txt', ('\n'.join(omitted) or 'none') .encode() + b'\n')
    print(str(outfile))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--hdm-log-dir', required=True)
    args = parser.parse_args()
    collect(args.output_dir, args.hdm_log_dir)
