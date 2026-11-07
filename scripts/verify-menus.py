#!/usr/bin/env python3
import pathlib, sys
p = pathlib.Path(__file__).resolve().parent.parent / 'ui/menus.tsv'
entries = []
for n, line in enumerate(p.read_text(encoding='utf-8').splitlines(), 1):
    if not line or line.startswith('#'): continue
    x=line.split('|')
    if len(x)!=4: sys.exit(f'bad menu row {n}')
    entries.append(x)
ids={r[3] for r in entries}
if len(ids)!=len(entries): sys.exit('duplicate menu ids')
for r in entries:
    if r[0]!='root' and r[0] not in ids: sys.exit(f'unknown parent: {r}')
assert len(entries)>=440, 'menu spec incomplete'
assert len([r for r in entries if r[0]=='root'])==10, 'main menu mismatch'
print(f'Menu structure valid: {len(entries)} entries, 10 main headings')
