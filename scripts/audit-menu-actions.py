#!/usr/bin/env python3
"""Audit the simplified menu plus retained internal legacy handlers."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
rows = [line.split("|") for line in (root / "ui/menus.tsv").read_text().splitlines()
        if line and not line.startswith("#")]
old = [line.split("|") for line in (root / "ui/legacy-menus.tsv").read_text().splitlines()
       if line and not line.startswith("#")]
parents = {r[0] for r in rows}
legacy_parents = {r[0] for r in old}
new_leaves = {r[3]: r for r in rows if r[3] not in parents}
legacy_leaves = {r[3]: r for r in old if r[3] not in legacy_parents}
targets = {}
for line in (root / "ui/menu-targets.tsv").read_text().splitlines():
    if line and not line.startswith("#"):
        m, target = line.split("|")
        assert m not in targets
        targets[m] = target
assert set(new_leaves) == set(targets)
actions = (root / "ui/actions.sh").read_text()
routes = {}
for match in re.finditer(r"(?m)^\s{2}([0-9][0-9.A-Z|]*)\)\s*(.+?);;\s*$", actions):
    for old_id in match.group(1).split("|"):
        assert old_id not in routes, old_id
        routes[old_id] = match.group(2)
assert set(routes) == set(legacy_leaves), {"missing": set(legacy_leaves)-set(routes)}
new_actions = (root / "ui/actions_v2.sh").read_text()
custom = set(re.findall(r"(?m)^\s{4}([a-z][a-z0-9-]+)\)\s*[^\n]+;;", new_actions))
mapped_legacy = set()
for menu_id, target in targets.items():
    if target.startswith("new:"):
        assert target[4:] in custom, (menu_id, target)
    else:
        assert target in routes, (menu_id, target)
        mapped_legacy.add(target)
assert mapped_legacy <= set(legacy_leaves)
# Critical user-facing navigation must retain audited, concrete implementation.
expect = {
    "4.8.1": "hdm_action_desktop_remove_preview",
    "6.10.1": "hdm_action_remove_preview rustdesk",
    "10.8.8": "hdm_diag_prune_logs",
    "2.8.4": "hdm_action_display_remove_preview",
    "9.2.1": "hdm_quick_install",
    "4.8.3": "hdm_display_remove_config",
}
for action_id, function in expect.items():
    assert function in routes[action_id], (action_id, function)
warnings = sum(routes[x].startswith("hdm_warn ") for x in mapped_legacy)
print(f"PASS compact menu audit: {len(rows)} entries, {len(new_leaves)} visible actions, "
      f"{len(routes)} old actions retained internally, {len(custom)} new handlers, "
      f"{warnings} informational legacy handlers, no orphan routes")
