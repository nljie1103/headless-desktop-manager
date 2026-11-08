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
assert nodes[4].detail == "1920x1080"
assert nodes[6].value == "123456"
assert "外部" not in nodes[6].detail
# A real connected Xrandr virtual display should turn the first node green,
# even if /sys/class/drm is hidden by a cloud/container environment.
with patch.object(chain, "session_display", return_value=""):
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

# A running GDM3 greeter alone cannot turn missing user-session and display
# into a falsely green success chain.
without_user = {**base, "sessions": [],
                "display": {**base["display"], "x11_socket_paths": []}}
nodes_empty = chain.build(without_user, {"manager": "gdm3", "drm": "disconnected",
                                         "resolution": "", "rustdesk_id": ""})
assert nodes_empty[0].state == "bad" and nodes_empty[4].state == "bad"
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

# The JSON entry point must not emit ANSI, errors, credentials, or interactive prompts.
p = subprocess.run(["bash", str(root / "hdm.sh"), "--chain-json"],
                   capture_output=True, text=True, check=True, timeout=20)
actual = json.loads(p.stdout)
assert len(actual) == 7
assert all(set(n) == set(vars(nodes[0])) for n in actual)
assert not ("password" in p.stdout.lower() or "auth_token" in p.stdout)
assert not p.stderr
print("PASS 7-node chain status, graph widths, X11/Wayland, active desktop, paths and JSON")
