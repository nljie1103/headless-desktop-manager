#!/usr/bin/env python3
"""Verify the axis-ordered eight-section UI and retained explicit action mapping."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
rows = []
for idx, raw in enumerate((root / "ui/menus.tsv").read_text(encoding="utf-8").splitlines(), 1):
    if not raw or raw.startswith("#"):
        continue
    parts = raw.split("|")
    if len(parts) != 4:
        sys.exit(f"Invalid menu row {idx}")
    rows.append(parts)

ids = {r[3] for r in rows}
if len(ids) != len(rows):
    sys.exit("Duplicate menu IDs")
parents = {r[0] for r in rows}
for row in rows:
    if row[0] != "root" and row[0] not in ids:
        sys.exit(f"Orphan menu parent: {row}")
    if row[0] != "root" and row[3].rsplit(".", 1)[0] != row[0]:
        sys.exit(f"Wrong hierarchical menu ID: {row}")

roots = [r[2] for r in rows if r[0] == "root"]
expected = ["显示输出", "登录管理器", "图形协议", "桌面环境",
            "图形会话", "RustDesk", "设备 ID", "HDM 管理"]
assert roots == expected, roots

mapped = {}
for raw in (root / "ui/menu-targets.tsv").read_text(encoding="utf-8").splitlines():
    if not raw or raw.startswith("#"):
        continue
    parts = raw.split("|")
    if len(parts) != 2 or parts[0] in mapped:
        sys.exit(f"Invalid/duplicate target: {raw}")
    mapped[parts[0]] = parts[1]

leaves = ids - parents
assert set(mapped) == leaves, {"missing": sorted(leaves - mapped.keys()),
                               "orphan": sorted(mapped.keys() - leaves)}
assert 40 <= len(rows) <= 80 and 30 <= len(mapped) <= 70
assert all(r[3].count(".") <= 2 for r in rows), "More than 3 menu levels"
result = subprocess.run([sys.executable, str(root / "scripts/build-menus-v2.py"), "--check"],
                        capture_output=True, text=True, check=False)
assert result.returncode == 0, result.stdout + result.stderr
print(f"Menu structure valid: {len(rows)} entries, 8 sections, {len(mapped)} routed leaves")
