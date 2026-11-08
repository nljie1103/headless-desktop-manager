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
          group("安装", item("1.1"), item("1.2"), item("1.3")),
          group("卸载", item("2.8")),
          group("更新与修复", item("2.2"), item("2.7")),
          group("分辨率与色深", item("2.4")),
          group("查看显示状态", item("2.1")),
          group("切换显示方案", item("2.3")),
          group("启动与自启", item("2.5"), item("2.6")),
          group("方案推荐与对比", item("1.4"), item("1.5")),
          group("配置备份与恢复", item("2.9")),
          group("显示故障诊断", item("10.2"))),
    group("登录管理器管理",
          group("安装",
                item("3.1.4", "安装 GDM3"),
                custom("安装 LightDM 与登录界面", "new:dm-install-lightdm"),
                item("3.2.3", "LightDM 配置指南")),
          group("卸载",
                custom("预览 GDM3 卸载范围", "new:dm-uninstall-preview-gdm"),
                custom("预览 LightDM 卸载范围", "new:dm-uninstall-preview-lightdm"),
                custom("卸载安全说明", "new:dm-uninstall-guide")),
          group("更新",
                custom("查看 GDM3 / LightDM 版本", "new:dm-versions"),
                custom("更新 GDM3", "new:dm-upgrade-gdm"),
                custom("更新 LightDM", "new:dm-upgrade-lightdm")),
          group("状态与配置", item("4.4")),
          group("服务检查", item("10.7.3"), item("4.5.3")),
          group("故障与日志", item("10.3.2"), item("4.5.6"))),
    group("图形协议管理",
          group("查看 X11 / Wayland", item("4.5.1"), item("4.5.2"),
                custom("图形协议结构说明", "new:protocol-guide")),
          group("Xorg 环境", item("10.2.2"), item("10.2.3"), item("2.1.1"),
                item("3.1.5", "GNOME Xorg 配置（旧版系统）")),
          group("Wayland / Portal", item("4.6.6"), item("4.5.7")),
          group("协议兼容与诊断", item("10.3.3"), item("10.2.6"),
                item("3.2.4", "检查 XFCE X11"), item("3.3.4", "检查 MATE X11"))),
    group("桌面环境管理",
          group("安装", item("3.1"), item("3.2"), item("3.3")),
          group("卸载与预览", item("4.8")),
          group("更新", item("4.2")),
          group("切换桌面", item("4.3")),
          group("已装桌面与版本", item("4.1"), item("3.6")),
          group("推荐与比较", item("3.4"), item("3.5")),
          group("GNOME 专项", item("4.6")),
          group("修复桌面", item("4.7")),
          group("配置备份与恢复", item("4.9")),
          group("桌面故障", item("10.3"))),
    group("图形会话管理",
          group("查看会话状态", item("4.5")),
          group("分辨率与 DISPLAY", item("4.6.3"), item("10.2.4")),
          group("D-Bus / 用户会话", item("10.3.4"), item("4.5.4")),
          group("锁屏与空闲", item("4.6.4")),
          group("会话日志与修复", item("10.3.7"), item("10.3.8"),
                item("10.3.9"), item("4.5.9"))),
    group("RustDesk 管理",
          group("安装", *(item(f"5.{i}") for i in range(1, 9))),
          group("卸载", item("6.10")),
          group("更新", *(item(f"6.{i}") for i in range(1, 10))),
          group("配置 ID / 中继 / Key",
                *(item(f"7.{i}") for i in (1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13))),
          group("服务状态与故障", item("10.4"))),
    group("设备 ID 与设备信息",
          group("查看设备 ID", item("7.8.1"), item("7.8.5")),
          group("设备 ID 管理", item("7.8.2"), item("7.8.3"), item("7.8.4")),
          group("系统 / 内核 / 架构", item("10.11")),
          group("RustDesk 版本与兼容性", item("5.6.1"), item("5.7.1"), item("10.4.1")),
          group("设备网络信息", item("10.5.7"))),
    group("HDM 脚本管理",
          group("更新脚本", *(item(f"8.{i}") for i in (1, 2, 3, 4, 5))),
          group("卸载脚本",
                custom("预览卸载范围", "new:script-uninstall-preview"),
                custom("卸载 HDM（保留配置与日志）", "new:script-uninstall")),
          group("查看更新日志", item("8.7")),
          group("查看安装日志", item("10.8.1"), item("10.8.9"), item("9.6")),
          item("10.8.7", "快速导出全部日志"),
          group("全部日志", item("10.8")),
          group("系统诊断与修复", item("10.1"), item("10.5"), item("10.6"),
                item("10.7"), item("10.10")),
          group("智能安装与续装", *(item(f"9.{i}") for i in range(1, 8))),
          group("系统配置备份", item("10.9")),
          group("模块、完整性与设置", *(item(f"8.{i}") for i in (6, 8, 9, 10)))),
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
