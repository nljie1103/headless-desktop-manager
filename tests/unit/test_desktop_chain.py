#!/usr/bin/env python3
"""Seven-node desktop chain regression tests (pure fixture checks + installed CLI)."""
from __future__ import annotations
import json
import pathlib
import re
import subprocess
import sys
from unittest.mock import patch

root = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "modules/diagnostics"))
import desktop_chain as chain

base = {
    "packages": {name: {"installed": True, "version": ver} for name, ver in
                 [("gdm3", "46.2-1"), ("xfce4-session", "4.18.3-1"), ("gnome-shell", "46.0"),
                  ("xserver-xorg-core", "2:21.1.12-1"), ("rustdesk", "1.5.1")]},
    "display": {"gdm3_service": "active", "lightdm_service": "inactive",
                "x11_socket_paths": ["X0"], "hdm_dummy_config_present": False},
    "sessions": [{"id": "c2", "class": "user", "state": "active",
                  "type": "x11", "desktop": "xfce"}],
    "rustdesk": {"service": "active"},
}
signals = {"manager": "gdm3", "drm": "connected",
           "resolution": "1920x1080", "rustdesk_id": "123456"}
with patch.object(chain, "session_display", return_value=":0"):
    nodes = chain.build(base, signals)
assert len(nodes) == 7
assert [n.name for n in nodes] == [
    "显示输出", "登录管理器", "图形协议", "桌面环境", "图形会话", "RustDesk", "设备 ID"]
assert all(n.state == "ok" for n in nodes), nodes
assert nodes[1].value.startswith("GDM3")
assert nodes[3].value == "XFCE"  # active XFCE overrides installed GNOME
assert nodes[4].detail == "分辨率待核实"  # xrandr DISPLAY not yet linked to session
assert nodes[6].value == "123456"
assert "外部" not in nodes[6].detail
# A real connected Xrandr virtual display should turn the first node green,
# even if /sys/class/drm is hidden by a cloud/container environment.
with patch.object(chain, "session_display", return_value=":0"):
    virtual = chain.build(base, {**signals, "drm":"unknown", "xrandr_output":"DUMMY0",
                                 "xrandr_display":":0"})
assert virtual[0].state == "ok" and "DUMMY0" in virtual[0].value
assert virtual[0].detail == "1920x1080"
assert ":0" in virtual[4].value
with patch.dict("os.environ", {"DISPLAY":":0"}):
    sample = ("Screen 0: minimum 64 x 64, current 1280 x 800\n"
              "DUMMY0 connected primary 1280x800+0+0 0mm x 0mm\n")
    with patch.object(chain, "run", return_value=sample):
        assert chain.xrandr_current() == ("1280x800", "DUMMY0")
    with patch.object(chain, "run", return_value="Screen 0: current 1280 x 800\n"):
        assert chain.xrandr_current() == ("", "")  # no provable output
for width in (24, 36, 53, 67, 80, 106, 107, 120, 145, 190):
    rendered = chain.render(nodes, width, enabled=False)
    assert not re.search(r"\x1b\[", rendered)
    assert "设备 ID" in rendered or "设备 ID" in chain.render(nodes, width, details=True)
    for line in rendered.splitlines():
        assert chain.text_width(line) <= max(26, width), (width, chain.text_width(line), line)
assert "\x1b[32m" in chain.render(nodes, 145, enabled=True)
assert "/etc/X11/default-display-manager" in chain.render(nodes, 80, details=True)
assert "本机检测" in chain.render(nodes, 80)
for width in (32, 50, 80, 110, 145):
    compact = chain.render(nodes, width, enabled=False, footer=False)
    assert "设备 ID" in compact and "显示输出" in compact
    for redundant in ("绿=本地通过", "●=本地通过", "●正常", "本机检测不代表",
                      "远端控制另行实测", "必需软件包：缺失"):
        assert redundant not in compact, (redundant, compact)
    for line in compact.splitlines():
        assert chain.text_width(line) <= max(26, width), (width, line)
# Full --chain remains explanatory, with status legend and detailed paths.
assert "●=本地通过" in chain.render(nodes, 80)
assert "/etc/X11/default-display-manager" in chain.render(nodes, 80, details=True)

# A running GDM3 greeter alone cannot turn missing user-session and display
# into a falsely green success chain.
without_user = {**base, "sessions": [],
                "display": {**base["display"], "x11_socket_paths": []}}
nodes_empty = chain.build(without_user, {"manager": "gdm3", "drm": "disconnected",
                                         "resolution": "", "rustdesk_id": ""})
assert nodes_empty[0].state == "bad" and nodes_empty[4].state == "unknown"
assert nodes_empty[1].state == "ok" and nodes_empty[6].state == "unknown"

wayland = {**base,
           "sessions": [{"id": "x1", "class": "user", "state": "active",
                         "type": "wayland", "desktop": "gnome"}],
           "display": {**base["display"], "x11_socket_paths": []}}
nodes_wayland = chain.build(wayland, {"manager": "gdm3", "drm": "unknown",
                                       "resolution": "", "rustdesk_id": ""})
assert nodes_wayland[2].value == "Wayland"
assert nodes_wayland[2].state == "ok"
assert nodes_wayland[0].state == "unknown"  # no inferred virtual monitor
assert nodes_wayland[3].value == "GNOME"
assert nodes_wayland[5].state == "unknown"  # Wayland needs Portal/PipeWire
ready_wayland = {**wayland, "packages": {**wayland["packages"], **{
    p: {"installed": True, "version": "1.0"}
    for p in ("pipewire", "xdg-desktop-portal", "xdg-desktop-portal-gnome")
}}}
assert chain.build(ready_wayland, {"manager": "gdm3", "drm": "unknown",
                                  "resolution": "", "rustdesk_id": ""})[5].state == "ok"

# Two login managers installed does NOT mean both are simultaneously
# running; the axis should show the actual active service and the other package.
installed_both = {**base, "packages": {**base["packages"],
    "lightdm": {"installed": True, "version": "1.26"}}}
with patch.object(chain, "session_display", return_value=":0"):
    one_manager = chain.build(installed_both, signals)
assert one_manager[1].state == "ok" and "GDM3" in one_manager[1].value
assert "另装LightDM" in one_manager[1].detail
# Both packages installed with neither service active still shows both names.
no_running = {**installed_both, "display": {**base["display"],
    "gdm3_service": "inactive", "lightdm_service": "inactive"}}
none_running = chain.build(no_running, {**signals, "manager": ""})
assert none_running[1].state == "bad"
assert "GDM3 + LightDM" in none_running[1].value
assert "服务未运行" in none_running[1].detail

# Both services active cannot be green -- even with one configured default.
dual_manager = {**installed_both,
    "display": {**base["display"], "lightdm_service": "active"}}
both = chain.build(dual_manager, signals)
assert both[1].state == "unknown" and "GDM3 + LightDM" in both[1].value
assert "双服务运行" in both[1].detail
assert "默认GDM3" in both[1].detail
# Default selected GDM3 but actual service LightDM only: expose mismatch.
wrong_default = {**installed_both, "display": {**base["display"],
    "gdm3_service": "inactive", "lightdm_service": "active"}}
mismatched = chain.build(wrong_default, signals)
assert mismatched[1].state == "unknown" and mismatched[1].value.startswith("LightDM")
assert "默认GDM3" in mismatched[1].detail
# Two *graphical user* sessions must not select the first desktop, DISPLAY,
# protocol or Xrandr resolution as definitive. One is active, one online.
dual_sessions = {**installed_both, "sessions": [
    {"id":"c2", "class":"user", "state":"active", "type":"x11", "desktop":"xfce"},
    {"id":"c3", "class":"user", "state":"online", "type":"wayland", "desktop":"gnome"}]}
with patch.object(chain, "session_display", return_value=":0"):
    multi = chain.build(dual_sessions, {**signals, "xrandr_output": "DUMMY0", "xrandr_display": ":0"})
assert len(multi) == 7
assert multi[2].state == "unknown" and "X11" in multi[2].value and "Wayland" in multi[2].value
assert multi[3].state == "unknown" and "XFCE" in multi[3].value and "GNOME" in multi[3].value
assert multi[4].state == "unknown" and multi[4].value == "多会话 2"
assert "c2:XFCE/X11" in multi[4].detail and "c3:GNOME/Wayland" in multi[4].detail
assert "1920x1080" not in multi[4].detail
assert multi[5].state == "unknown" and multi[6].state == "unknown"
assert multi[0].value == "DRM 已连接"  # no arbitrary session xrandr association
# Reversed listing must still show both protocols and desktops.
rev = chain.build({**dual_sessions, "sessions": list(reversed(dual_sessions["sessions"]))}, signals)
assert rev[2].state == "unknown" and "X11" in rev[2].value and "Wayland" in rev[2].value
assert rev[3].state == "unknown" and "GNOME" in rev[3].value and "XFCE" in rev[3].value
# Two sessions using the same protocol and desktop still count as two.
same = chain.build({**dual_sessions, "sessions": [dual_sessions["sessions"][0],
    {**dual_sessions["sessions"][0], "id":"c4", "state":"online"}]}, signals)
assert same[2].value == "X11×2" and same[3].value == "XFCE×2"
assert same[4].state == "unknown" and same[5].state == "unknown"
# A single session with a different DISPLAY from the caller's xrandr cannot
# inherit the caller's resolution or claimed connected DUMMY0.
with patch.object(chain, "session_display", return_value=":1"):
    mismatch_display = chain.build(installed_both, {**signals,
        "xrandr_output":"DUMMY0", "xrandr_display":":0"})
assert mismatch_display[4].detail == "分辨率待核实"
assert mismatch_display[0].value == "DRM 已连接"
# Large session lists are capped for performance but never presented as one
# certain graphical session just because only one appears in the scan.
cutoff = chain.build({**base, "sessions_truncated": True}, signals)
assert all(cutoff[idx].state == "unknown" for idx in (2,3,4,5))
assert "超限" in cutoff[4].value
# Non-graphical SSH/TTY and greeter sessions cannot masquerade as user desktops.
not_users = chain.build({**base, "sessions": [
    {"id":"c1", "class":"greeter", "state":"active", "type":"wayland", "desktop":"gnome"},
    {"id":"c2", "class":"user", "state":"active", "type":"tty", "desktop":""}]}, signals)
assert not_users[4].state == "unknown"
# With connected DRM + Xorg installed but no login session, say what is
# installed instead of blaming DRM or declaring the protocol unrecognized.
assert chain.build({**without_user, "sessions": []}, signals)[2].value == "Xorg 已安装"

# A headless XFCE/LightDM/RustDesk host can have every package installed but
# no *logged-in* user. Inventory must say 0 missing, DM pending start, user
# pending login; it must never declare GNOME/GDM3 missing.
xfce_host = {
    "system": {"id": "ubuntu", "version_id": "26.04"},
    "packages": {name: {"installed": True, "version": "1.0"} for name in (
        "xfce4-session", "xserver-xorg-core", "dbus-x11", "lightdm",
        "lightdm-gtk-greeter", "rustdesk")},
    "display": {"lightdm_service": "inactive", "gdm3_service": "inactive",
                "x11_socket_paths": []},
    "sessions": [], "rustdesk": {"service": "active"},
}
xfce_signals = {"manager": "lightdm", "drm": "connected", "resolution": "", "rustdesk_id": ""}
xfce_nodes = chain.build(xfce_host, xfce_signals)
assert xfce_nodes[0].state == "ok" and xfce_nodes[0].value == "DRM 已连接"
assert xfce_nodes[1].state == "unknown" and "LightDM" in xfce_nodes[1].value
assert xfce_nodes[2].state == "unknown" and "Xorg 已安装" in xfce_nodes[2].value
assert xfce_nodes[3].state == "ok" and xfce_nodes[3].value == "XFCE"
assert xfce_nodes[4].state == "unknown" and "未登录" in xfce_nodes[4].value
inventory = chain.home_inventory(xfce_host, xfce_signals, 86)
assert "必需软件包：缺失 0 项" in inventory, inventory
for component in ("XFCE 会话", "Xorg（X11）", "D-Bus X11", "LightDM 登录管理器", "LightDM GTK Greeter", "RustDesk"):
    assert "[已安装] " + component in inventory, component
assert "[待启动] LightDM 登录服务" in inventory
assert "[待登录] 图形用户会话" in inventory
assert "[缺失] GNOME" not in inventory and "[缺失] GDM3" not in inventory
assert "无需再装 Dummy/VKMS" in inventory
# Missing actual requirements must be visible without discarding other statuses.
without_greeter = {**xfce_host, "packages": {**xfce_host["packages"],
    "lightdm-gtk-greeter": {"installed": False, "version": None}}}
missing_inv = chain.home_inventory(without_greeter, xfce_signals, 70)
assert "[缺失] LightDM GTK Greeter" in missing_inv
assert "必需软件包：缺失 1 项" in missing_inv
for width in (40, 66, 80, 110):
    assert all(chain.text_width(line) <= max(24, width - 2)
               for line in chain.home_inventory(xfce_host, xfce_signals, width).splitlines())
# For GNOME/Wayland, Xorg absent is not a missing requirement.
gnome_host = {**xfce_host, "packages": {name: {"installed": True, "version": "1.0"} for name in (
    "gnome-shell", "gdm3", "pipewire", "xdg-desktop-portal", "xdg-desktop-portal-gnome", "rustdesk")},
    "display": {"gdm3_service": "active", "lightdm_service": "inactive", "x11_socket_paths": []}}
gnome_signals = {**xfce_signals, "manager": "gdm3"}
assert chain.build(gnome_host, gnome_signals)[2].value == "Wayland 待登录"
assert "必需软件包：缺失 0 项" in chain.home_inventory(gnome_host, gnome_signals)
assert "[缺失] Xorg" not in chain.home_inventory(gnome_host, gnome_signals)

# The JSON entry point must not emit ANSI, errors, credentials, or interactive prompts.
p = subprocess.run(["bash", str(root / "hdm.sh"), "--chain-json"],
                   capture_output=True, text=True, check=True, timeout=20)
actual = json.loads(p.stdout)
assert len(actual) == 7
assert all(set(n) == set(vars(nodes[0])) for n in actual)
assert not ("password" in p.stdout.lower() or "auth_token" in p.stdout)
assert not p.stderr
print("PASS 7-node chain, dual managers and concurrent user sessions, DISPLAY match, truncated scans and JSON")
