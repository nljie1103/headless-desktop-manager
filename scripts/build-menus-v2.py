#!/usr/bin/env python3
"""Deterministically construct the eight-stage HDM user menu.

Keep old (v4.2) action identifiers stable: menu-targets.tsv maps new user-visible
IDs to tested legacy dispatch IDs. The new menu never evals a target.
"""
from __future__ import annotations
from collections import defaultdict
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
legacy = root / "ui/legacy-menus.tsv"
menus = root / "ui/menus.tsv"
targets = root / "ui/menu-targets.tsv"
original = {}
children: dict[str, list[str]] = defaultdict(list)
for raw in legacy.read_text(encoding="utf-8").splitlines():
    if not raw or raw.startswith("#"):
        continue
    parent, key, label, old_id = raw.split("|")
    assert old_id not in original, old_id
    original[old_id] = (parent, key, label)
    children[parent].append(old_id)
legacy_leaves = {old_id for old_id in original if old_id not in children}


def group(title, *items):
    return ("group", title, items)


def item(old_id, label=None):
    assert old_id in original, old_id
    return ("ref", old_id, label)


def custom(title, target):
    return ("custom", title, target)


MAIN = [
    group("显示输出管理",
          item("1.1.1", "安装 Xorg Dummy"),
          item("1.2.1", "安装 Xvfb"),
          item("1.3.2", "启用 VKMS"),
          custom("查看显示状态", "new:display-status"),
          item("2.8.1", "删除 HDM Dummy 配置"),
          group("分辨率设置", item("2.4")),
          group("高级显示工具",
                item("1.1"), item("1.2"), item("1.3"), item("1.4"), item("1.5"),
                item("2.8"), item("2.2"), item("2.7"), item("2.1"),
                item("2.3"), item("2.5"), item("2.6"), item("2.9"), item("10.2"))),
    group("登录管理器管理",
          item("3.1.4", "安装 GDM3"),
          custom("安装 LightDM", "new:dm-install-lightdm"),
          custom("卸载 GDM3", "new:dm-remove-gdm3"),
          custom("卸载 LightDM", "new:dm-remove-lightdm"),
          custom("更新当前登录管理器", "new:dm-upgrade-current"),
          custom("查看登录管理器状态", "new:dm-versions"),
          group("切换默认登录管理器",
                custom("选择 LightDM", "new:dm-select-lightdm"),
                custom("选择 GDM3", "new:dm-select-gdm3")),
          group("高级登录工具",
                item("3.2.3", "LightDM 配置指南"), item("4.4"),
                item("10.7.3"), item("4.5.3"), item("10.3.2"), item("4.5.6"),
                custom("卸载风险说明", "new:dm-uninstall-guide"),
                custom("更新 GDM3（指定）", "new:dm-upgrade-gdm"),
                custom("更新 LightDM（指定）", "new:dm-upgrade-lightdm"),
                custom("查看 GDM3 / LightDM 版本", "new:dm-versions"))),
    group("图形协议管理",
          item("4.5.2", "查看当前图形协议"),
          item("10.2.2", "检查 Xorg / Xvfb"),
          custom("X11 / Wayland 说明", "new:protocol-guide"),
          group("高级协议诊断",
                item("4.5.1"), item("10.2.3"), item("2.1.1"),
                item("3.1.5", "GNOME Xorg 配置（旧版）"),
                item("4.6.6"), item("4.5.7"), item("10.3.3"),
                item("10.2.6"), item("3.2.4"), item("3.3.4"))),
    group("桌面环境管理",
          custom("安装 XFCE + Xorg + LightDM", "new:desktop-install-xfce"),
          custom("安装 GNOME", "new:desktop-install-gnome"),
          custom("安装 MATE + Xorg + LightDM", "new:desktop-install-mate"),
          custom("卸载 GNOME", "new:desktop-remove-gnome"),
          custom("卸载 XFCE", "new:desktop-remove-xfce"),
          custom("卸载 MATE", "new:desktop-remove-mate"),
          custom("更新当前桌面", "new:desktop-update"),
          item("4.1.1", "查看桌面状态"),
          group("切换桌面", item("4.3")),
          group("高级桌面工具",
                item("3.1"), item("3.2"), item("3.3"), item("4.2"),
                item("4.1"), item("3.6"), item("3.4"), item("3.5"),
                item("4.6"), item("4.7"), item("4.8"), item("4.9"), item("10.3"))),
    group("图形会话管理",
          item("4.5.1", "查看会话"),
          item("4.6.3", "查看实际分辨率"),
          item("4.5.9", "修复无图形会话"),
          group("高级会话工具",
                item("4.5"), item("10.2.4"), item("10.3.4"),
                item("4.6.4"), item("10.3.7"), item("10.3.8"), item("10.3.9"))),
    group("RustDesk 管理",
          custom("安装 RustDesk", "new:rustdesk-install"),
          custom("卸载 RustDesk", "new:rustdesk-remove"),
          custom("更新 RustDesk", "new:rustdesk-update"),
          group("配置 ID / 中继 / Key",
                *(item(f"7.{i}") for i in (1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13))),
          item("7.8.1", "查看设备 ID"),
          group("诊断 RustDesk", item("10.4")),
          group("高级安装与版本回滚",
                *(item(f"5.{i}") for i in range(1, 9)), item("6.10"),
                *(item(f"6.{i}") for i in range(1, 10)))),
    group("设备 ID 与设备信息",
          item("7.8.1", "查看设备 ID"),
          item("7.8.5", "查看设备注册状态"),
          item("10.11", "系统 / 内核 / 架构"),
          group("高级设备工具",
                item("7.8.2"), item("7.8.3"), item("7.8.4"),
                item("5.6.1"), item("5.7.1"), item("10.4.1"), item("10.5.7"))),
    group("HDM 脚本管理",
          custom("更新 HDM（最新正式版）", "new:script-update"),
          custom("卸载 HDM（保留数据）", "new:script-uninstall"),
          item("10.8.7", "导出诊断日志"),
          item("10.8.1", "查看安装日志"),
          group("更新记录", item("8.7")),
          group("系统检查", item("10.1")),
          group("高级维护",
                item("10.8.9"), item("9.6"), item("10.8"),
                item("10.5"), item("10.6"), item("10.7"), item("10.10"),
                *(item(f"9.{i}") for i in range(1, 8)), item("10.9"),
                *(item(f"8.{i}") for i in range(1, 11)),
                custom("查看脚本卸载范围", "new:script-uninstall-preview"))),
]

new_rows = ["# parent|selection|label|menu_id"]
new_targets = ["# menu_id|dispatch_target"]
mapped_old = set()


def append(parent: str, number: int, spec) -> str:
    kind = spec[0]
    menu_id = str(number) if parent == "root" else f"{parent}.{number}"
    if kind == "group":
        _, label, entries = spec
        target = None
    elif kind == "ref":
        _, old_id, override_label = spec
        label = override_label or original[old_id][2]
        entries = [item(child) for child in children.get(old_id, [])]
        target = old_id if not entries else None
    elif kind == "custom":
        _, label, target = spec
        assert target.startswith("new:")
        entries = []
    else:
        raise ValueError(spec)
    assert not any("|" in str(v) or "\n" in str(v) for v in (label, menu_id))
    new_rows.append("|".join((parent, str(number), label, menu_id)))
    if target is not None:
        new_targets.append(menu_id + "|" + target)
        if not target.startswith("new:"):
            mapped_old.add(target)
    for index, child in enumerate(entries, 1):
        append(menu_id, index, child)
    return menu_id


for index, spec in enumerate(MAIN, 1):
    append("root", index, spec)

missing = legacy_leaves - mapped_old
if missing:
    raise AssertionError("Legacy actions not reachable: " + ", ".join(sorted(missing)))
assert len(MAIN) == 8
target_text = "\n".join(new_targets) + "\n"
menu_text = "\n".join(new_rows) + "\n"

if "--check" in sys.argv:
    assert menus.read_text(encoding="utf-8") == menu_text, "menus.tsv out of date"
    assert targets.read_text(encoding="utf-8") == target_text, "menu-targets.tsv out of date"
else:
    menus.write_text(menu_text, encoding="utf-8")
    targets.write_text(target_text, encoding="utf-8")
print(f"HDM v2 menus: {len(new_rows)-1} entries, {len(new_targets)-1} routed leaves, "
      f"{len(mapped_old)}/{len(legacy_leaves)} distinct original actions preserved")
