#!/usr/bin/env python3
"""Build the task-first HDM menu; keep legacy handlers internal for compatibility.

The visible UI intentionally has only six sections and at most three menu levels.
Legacy action identifiers remain implemented in ui/actions.sh, not exposed as
hundreds of nested help/diagnostic entries.
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


def group(title, *items):
    return ("group", title, items)


def item(old_id, label=None):
    assert old_id in original, old_id
    assert old_id not in children, ("Only map leaf actions in normal UI", old_id)
    return ("ref", old_id, label)


def custom(title, target):
    return ("custom", title, target)


MAIN = [
    group("快速部署",
          custom("安装 / 补齐桌面和 RustDesk（先预览确认）", "new:quick-install"),
          custom("查看推荐安装计划", "new:quick-plan"),
          custom("启动登录界面", "new:dm-start"),
          custom("查看桌面就绪情况", "new:readiness")),
    group("桌面环境",
          custom("安装 XFCE（X11 推荐）", "new:desktop-install-xfce"),
          custom("安装 GNOME（Ubuntu 26 为 Wayland）", "new:desktop-install-gnome"),
          custom("安装 MATE（X11）", "new:desktop-install-mate"),
          custom("更新当前桌面", "new:desktop-update"),
          custom("卸载 XFCE", "new:desktop-remove-xfce"),
          custom("卸载 GNOME", "new:desktop-remove-gnome"),
          custom("卸载 MATE", "new:desktop-remove-mate"),
          item("4.1.1", "查看桌面状态"),
          group("图形会话与协议",
                custom("查看所有图形用户会话", "new:session-list"),
                custom("结束指定图形用户会话", "new:session-terminate"),
                custom("启动登录界面（准备新会话）", "new:session-prepare"),
                custom("查看 X11 / Wayland / Xorg 状态", "new:protocol-status"),
                custom("选择 LightDM 默认 X11 桌面（XFCE / MATE）", "new:session-select"))),
    group("登录管理器（LightDM / GDM3 选一个）",
          custom("安装 LightDM（XFCE 推荐）", "new:dm-install-lightdm"),
          custom("安装 GDM3（GNOME 推荐）", "new:dm-install-gdm3"),
          custom("启动当前登录管理器", "new:dm-start"),
          custom("停止当前登录管理器", "new:dm-stop"),
          custom("重启当前登录管理器", "new:dm-restart"),
          custom("启用开机自启", "new:dm-autostart-on"),
          custom("禁用开机自启", "new:dm-autostart-off"),
          custom("更新当前登录管理器", "new:dm-upgrade-current"),
          custom("卸载 LightDM", "new:dm-remove-lightdm"),
          custom("卸载 GDM3", "new:dm-remove-gdm3"),
          group("切换默认登录管理器",
                custom("选择 LightDM", "new:dm-select-lightdm"),
                custom("选择 GDM3", "new:dm-select-gdm3")),
          custom("查看当前状态", "new:dm-versions")),
    group("RustDesk 远程控制",
          custom("安装 RustDesk", "new:rustdesk-install"),
          custom("启动 RustDesk", "new:rustdesk-start"),
          custom("停止 RustDesk", "new:rustdesk-stop"),
          custom("重启 RustDesk", "new:rustdesk-restart"),
          custom("启用开机自启", "new:rustdesk-autostart-on"),
          custom("禁用开机自启", "new:rustdesk-autostart-off"),
          custom("更新 RustDesk", "new:rustdesk-update"),
          custom("卸载 RustDesk", "new:rustdesk-remove"),
          item("7.8.1", "查看设备 ID"),
          custom("配置自建 ID / 中继服务器", "new:rustdesk-server"),
          custom("设置无人值守密码", "new:rustdesk-password"),
          custom("查看 RustDesk 状态", "new:rustdesk-status")),
    group("显示设置（有画面则无需安装虚拟显示）",
          custom("查看显示输出", "new:display-status"),
          group("设置分辨率",
                item("2.4.1", "1280×720"),
                item("2.4.2", "1600×900"),
                item("2.4.3", "1920×1080"),
                item("2.4.4", "2560×1440"),
                item("2.4.5", "自定义分辨率"),
                item("2.4.7", "恢复默认分辨率")),
          group("缺少显示输出时的可选工具",
                item("1.1.1", "安装 Xorg Dummy"),
                item("1.2.1", "安装 Xvfb"),
                item("1.3.2", "启用 VKMS"),
                item("2.8.1", "移除 HDM 的 Dummy 配置")),
          custom("查看 X11 / Wayland 状态（不影响 DRM）", "new:protocol-status")),
    group("HDM 管理",
          custom("更新 HDM（最新正式版）", "new:script-update"),
          custom("卸载 HDM（保留数据）", "new:script-uninstall"),
          custom("诊断桌面和连接问题", "new:doctor"),
          item("10.8.7", "导出诊断日志"),
          item("10.8.1", "查看安装日志"),
          item("10.11.1", "查看系统与架构信息")),
]

new_rows = ["# parent|selection|label|menu_id"]
new_targets = ["# menu_id|dispatch_target"]


def append(parent: str, number: int, spec) -> str:
    kind = spec[0]
    menu_id = str(number) if parent == "root" else f"{parent}.{number}"
    if kind == "group":
        _, label, entries = spec
        target = None
    elif kind == "ref":
        _, old_id, override_label = spec
        label = override_label or original[old_id][2]
        entries = []
        target = old_id
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
    for index, child in enumerate(entries, 1):
        append(menu_id, index, child)
    return menu_id


for index, spec in enumerate(MAIN, 1):
    append("root", index, spec)

assert len(MAIN) == 6
menu_text = "\n".join(new_rows) + "\n"
target_text = "\n".join(new_targets) + "\n"

if "--check" in sys.argv:
    assert menus.read_text(encoding="utf-8") == menu_text, "menus.tsv out of date"
    assert targets.read_text(encoding="utf-8") == target_text, "menu-targets.tsv out of date"
else:
    menus.write_text(menu_text, encoding="utf-8")
    targets.write_text(target_text, encoding="utf-8")
print(f"HDM task-first menu: {len(new_rows)-1} entries, {len(new_targets)-1} actions, "
      f"{len(original)} retained legacy declarations")
