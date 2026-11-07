#!/usr/bin/env python3
"""Reject tar path traversal, links and devices before extracting a release asset."""
import sys
import tarfile
from pathlib import PurePosixPath

with tarfile.open(sys.argv[1], 'r:gz') as tar:
    members = tar.getmembers()
    if len(members) > 2000:
        raise SystemExit('too many archive entries')
    total_size = 0
    for m in members:
        p = PurePosixPath(m.name)
        if (p.is_absolute() or '..' in p.parts or not p.parts or
                p.parts[0] != 'headless-desktop-manager' or
                not (m.isfile() or m.isdir())):
            raise SystemExit(f'unsafe entry: {m.name}')
        total_size += m.size
        if total_size > 100 * 1024 * 1024:
            raise SystemExit('release uncompressed size too large')
print('archive paths and content types verified')
