#!/usr/bin/env python3
"""Check HDM commit-message subject format and reject placeholder subjects.

This checks syntax and obvious placeholders, not the factual truth of a change.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys

REQUIRED = re.compile(r'^v(?P<version>\d+\.\d+\.\d+) (?P<summary>\S.{6,})$')
GENERIC = re.compile(r'^(?:update files?|fix bugs?|bugfix|minor changes?|test|wip|xxx|修复问题|更新文件|修复bug|测试|日常更新|修复xxx)$', re.I)


def valid(message: str) -> tuple[bool, str]:
    m = REQUIRED.fullmatch(message.strip())
    if not m:
        return False, 'subject must begin with vX.Y.Z + a meaningful description (8+ chars)'
    body = m.group('summary').strip()
    if GENERIC.fullmatch(body) or 'xxx' in body.casefold():
        return False, 'generic or placeholder description is forbidden'
    return True, ''


def git_output(*args: str) -> str:
    return subprocess.check_output(['git', *args], text=True, encoding='utf-8')


def main() -> int:
    p = argparse.ArgumentParser()
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument('--message', help='validate a single subject line')
    group.add_argument('--range', dest='git_range', help='git revision range e.g. base..HEAD or HEAD')
    opts = p.parse_args()
    if opts.message is not None:
        values = [('manual', opts.message)]
    else:
        hashes = [s for s in git_output('rev-list', opts.git_range).splitlines() if s]
        values = [(sha[:12], git_output('show', '-s', '--format=%s', sha).strip()) for sha in hashes]
    failures = []
    for ref, subject in values:
        ok, error = valid(subject)
        if not ok:
            failures.append(f'{ref}: {subject!r} - {error}')
    if failures:
        print('Commit-message policy failed:\n' + '\n'.join(failures), file=sys.stderr)
        return 1
    print(f'PASS: {len(values)} commit message(s) meet HDM format policy')
    return 0


if __name__ == '__main__':
    sys.exit(main())
