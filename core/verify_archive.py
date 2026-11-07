#!/usr/bin/env python3
"""Reject tar path traversal, links and devices before extracting a release asset."""
import sys
import re
import tarfile
from pathlib import PurePosixPath

allowed_root = sys.argv[2] if len(sys.argv) > 2 else 'headless-desktop-manager'
if not re.fullmatch(r'headless-desktop-manager(?:-[0-9a-f]{40})?', allowed_root):
    raise SystemExit('invalid allowed archive root')
with tarfile.open(sys.argv[1], 'r:gz') as tar:
    members = tar.getmembers()
    if len(members) > 2000:
        raise SystemExit('too many archive entries')
    total_size = 0
    for m in members:
        p = PurePosixPath(m.name)
        if (p.is_absolute() or '..' in p.parts or not p.parts or
                p.parts[0] != allowed_root or
                not (m.isfile() or m.isdir())):
            raise SystemExit(f'unsafe entry: {m.name}')
        total_size += m.size
        if total_size > 100 * 1024 * 1024:
            raise SystemExit('release uncompressed size too large')
print('archive paths and content types verified')
