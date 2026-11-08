#!/usr/bin/env python3
"""Verify eight-stage UI hierarchy and the immutable v4.2 action mapping."""
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
expected = ["显示输出管理", "登录管理器管理", "图形协议管理",
            "桌面环境管理", "图形会话管理", "RustDesk 管理",
            "设备 ID 与设备信息", "HDM 脚本管理"]
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
assert len(rows) >= 470 and len(mapped) >= 381
result = subprocess.run([sys.executable, str(root / "scripts/build-menus-v2.py"), "--check"],
                        capture_output=True, text=True, check=False)
assert result.returncode == 0, result.stdout + result.stderr
print(f"Menu structure valid: {len(rows)} entries, 8 stages, {len(mapped)} routed leaves")
