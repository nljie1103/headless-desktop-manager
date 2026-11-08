#!/usr/bin/env python3
"""Production menu routing audit: reachability != functional verification."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
lines = (root / "ui/menus.tsv").read_text(encoding="utf-8").splitlines()
rows = [line.split("|") for line in lines if line and not line.startswith("#")]
assert all(len(row) == 4 for row in rows), "Invalid menu row"
all_ids = {row[3] for row in rows}
assert len(all_ids) == len(rows), "Duplicate menu ID"
parents = {row[0] for row in rows}
assert all(parent == "root" or parent in all_ids for parent in parents)
leaves = {row[3]: row for row in rows if row[3] not in parents}
actions = (root / "ui/actions.sh").read_text(encoding="utf-8")
routes = {}
for entry in re.finditer(r"(?m)^\s{2}([0-9][0-9.A-Z|]*)\)\s*(.+?);;\s*$", actions):
    for route in entry.group(1).split("|"):
        assert route not in routes, ("Duplicate route", route)
        routes[route] = entry.group(2)
assert set(routes) == set(leaves), {
    "missing": sorted(set(leaves) - set(routes)),
    "orphan": sorted(set(routes) - set(leaves)),
}
assert len(rows) == 481 and len(leaves) == 381
# Production-sensitive actions must not silently degrade to generic warning text.
required = {
    "4.8.1": "hdm_action_desktop_remove_preview",
    "6.10.1": "hdm_action_remove_preview rustdesk",
    "10.8.8": "hdm_diag_prune_logs",
    "2.8.4": "hdm_action_display_remove_preview",
    "9.2.1": "hdm_quick_install",
    "9.2.4": "hdm_action_other_desktop_plan",
    "4.8.3": "hdm_display_remove_config",
}
for route, handler in required.items():
    assert handler in routes[route], (route, routes[route])
# An informational-only route must not advertise mutating behavior without
# plainly labeling itself as a guide, limitation or information.
for route, action in routes.items():
    if not action.startswith("hdm_warn "):
        continue
    label = leaves[route][2]
    if any(word in label for word in ("卸载", "删除", "设置", "配置", "安装", "清理", "切换")):
        assert any(word in label for word in ("说明", "指南", "入口", "限制", "方式")), (route, label)
# These counts are explicit evidence scopes, NOT 381 feature success assertions.
warnings = sum(action.startswith("hdm_warn ") for action in routes.values())
print(f"PASS menu route audit: {len(rows)} entries, {len(leaves)} leaves, "
      f"{len(routes)} unique routes, {warnings} informational/limited handlers; "
      "zero missing/orphan routes")
