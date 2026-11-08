#!/usr/bin/env python3
"""Read-only desktop dependency chain for the HDM terminal header.

Status is local evidence, not proof of RustDesk external screen capture.
No credentials or configuration file bodies are read or printed.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unicodedata

sys.path.insert(0, str(Path(__file__).resolve().parent))
import status_json

STATUS_MARKS = {"ok": "●", "bad": "○", "unknown": "◆"}
STATUS_SIGNS = {"ok": "✓", "bad": "×", "unknown": "?"}
ANSI = {"ok": "\x1b[32m", "bad": "\x1b[31m", "unknown": "\x1b[33m"}
RESET = "\x1b[0m"


@dataclass
class Node:
    name: str
    state: str
    value: str
    detail: str
    path: str
    explanation: str


def run(*args: str, timeout: float = 2.0) -> str:
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=False, timeout=timeout)
        if result.returncode == 0:
            return result.stdout.strip()
    except (OSError, subprocess.TimeoutExpired, UnicodeError):
        pass
    return ""


def package(report: dict, key: str) -> dict:
    return report.get("packages", {}).get(key, {})


def version(report: dict, key: str) -> str:
    value = package(report, key).get("version")
    return str(value).split("-", 1)[0].split(":", 1)[-1] if value else "—"


def active_session(report: dict) -> dict | None:
    for session in report.get("sessions", []):
        if (session.get("class") == "user" and session.get("state") == "active"
                and session.get("type") in ("x11", "wayland")):
            return session
    for session in report.get("sessions", []):
        if (session.get("class") == "user" and session.get("state") == "online"
                and session.get("type") in ("x11", "wayland")):
            return session
    return None


def graphical_sessions(report: dict) -> list[dict]:
    # An online session can coexist with an active one (another seat or VT).
    # Never pick one arbitrarily when several graphical users are logged in.
    return [session for session in report.get("sessions", [])
            if session.get("class") == "user"
            and session.get("state") in ("active", "online")
            and session.get("type") in ("x11", "wayland")]


def desktop_name(session: dict | None) -> str:
    name = str((session or {}).get("desktop") or "").lower()
    if name.startswith("xfce"):
        return "XFCE"
    if name.startswith("mate"):
        return "MATE"
    if name.startswith(("gnome", "ubuntu")):
        return "GNOME"
    if name.startswith(("plasma", "kde")):
        return "KDE"
    return ""


def desktop_package(name: str) -> str:
    return {"XFCE": "xfce4-session", "MATE": "mate-session-manager",
            "GNOME": "gnome-shell", "KDE": "plasma-desktop"}.get(name, "")


def preferred_desktop(report: dict) -> str:
    for name in ("GNOME", "XFCE", "MATE", "KDE"):
        if package(report, desktop_package(name)).get("installed"):
            return name
    return ""


def default_display_manager(path: str = "/etc/X11/default-display-manager") -> str:
    try:
        text = Path(path).read_text(encoding="utf-8").strip()
    except OSError:
        return ""
    if text.endswith("/lightdm"):
        return "lightdm"
    if text.endswith("/gdm3") or text.endswith("/gdm"):
        return "gdm3"
    return ""


def drm_status(root: str = "/sys/class/drm") -> str:
    try:
        paths = list(Path(root).glob("*/status"))
    except OSError:
        return "unknown"
    seen = False
    uncertainty = False
    for path in paths:
        try:
            state = path.read_text(encoding="utf-8").strip()
        except OSError:
            continue
        seen = True
        if state == "connected":
            return "connected"
        if state not in ("disconnected",):
            uncertainty = True
    if seen and not uncertainty:
        return "disconnected"
    return "unknown"


def xrandr_current() -> tuple[str, str]:
    # Only probe the caller's already authenticated DISPLAY.
    # "connected + active mode" is stronger evidence than a Dummy config file.
    if not re.fullmatch(r":\d{1,3}(?:\.\d{1,2})?", os.getenv("DISPLAY", "")):
        return "", ""
    output = run("xrandr", "--current", timeout=2.0)
    connected = re.findall(
        r"(?m)^([A-Za-z0-9_.-]{1,32})\s+connected(\s+primary)?\s+"
        r"(\d{3,5})x(\d{3,5})\+\d+\+\d+", output)
    if connected:
        connected.sort(key=lambda item: bool(item[1]), reverse=True)
        name, _, width, height = connected[0]
        return f"{width}x{height}", name
    # A screen-size header alone does not establish that an output is connected.
    return "", ""


def session_display(session: dict | None) -> str:
    if not session:
        return ""
    sid = str(session.get("id", ""))
    if not re.fullmatch(r"[\w-]{1,48}", sid):
        return ""
    result = run("loginctl", "show-session", sid, "-p", "Display", "--value", timeout=1.5)
    return result if re.fullmatch(r":\d{1,3}(?:\.\d{1,2})?", result) else ""


def rustdesk_id() -> str:
    if os.getenv("HDM_HIDE_RUSTDESK_ID") == "1":
        return ""
    value = run("rustdesk", "--get-id", timeout=2.5)
    # Never allow CLI stderr, shell control characters or unexpected content into the header.
    return value if re.fullmatch(r"[A-Za-z0-9_-]{4,32}", value) else ""


def build(report: dict, signals: dict) -> list[Node]:
    graphical = graphical_sessions(report)
    multiple = len(graphical) > 1
    truncated = bool(report.get("sessions_truncated"))
    session = active_session(report) if not multiple and not truncated else None
    desktop = desktop_name(session)
    selected = desktop or preferred_desktop(report)
    session_type = (session or {}).get("type", "")
    actual_dm = signals.get("manager", "")
    display = report.get("display", {})
    drm = signals.get("drm", "unknown")
    has_socket = bool(display.get("x11_socket_paths"))
    has_dummy = bool(display.get("hdm_dummy_config_present"))
    res = signals.get("resolution", "")
    x_output = signals.get("xrandr_output", "")
    x_display = signals.get("xrandr_display", "")
    # xrandr reads the caller's DISPLAY, which may belong to a *different*
    # graphical session. Associate its resolution only with the unique session
    # if loginctl independently confirms the same DISPLAY.
    unique_display = session_display(session) if session_type == "x11" else ""
    real_x11_output = (not multiple and session_type == "x11"
                       and bool(x_output and res and unique_display == x_display)
                       and re.fullmatch(r":\d{1,3}(?:\.\d{1,2})?", x_display or "") is not None
                       and "X" + x_display[1:].split(".", 1)[0]
                           in display.get("x11_socket_paths", []))
    sid = str((session or {}).get("id") or "")
    service = report.get("rustdesk", {}).get("service")
    installed = bool(package(report, "rustdesk").get("installed"))
    got_id = signals.get("rustdesk_id", "")

    if real_x11_output:
        output = Node("显示输出", "ok", x_output + " 已连接", res,
                      "xrandr --current",
                      "当前 X11 DISPLAY 上已检测到连接并启用的显示输出；"
                      "可能是平台提供的虚拟屏，不代表 HDM 自行安装了 Dummy。")
    elif drm == "connected":
        output = Node("显示输出", "ok", "DRM 已连接", "输出可检测",
                      "/sys/class/drm", "内核报告显示输出已连接，尚需验证实际图像。")
    elif has_dummy:
        output = Node("显示输出", "unknown", "Dummy 已配置", "出图待确认",
                      "/etc/X11/xorg.conf.d/20-hdm-dummy.conf",
                      "配置存在不等于 Xorg 已使用此虚拟输出。")
    elif graphical:
        output = Node("显示输出", "unknown", "已见图形会话", "DRM 未确认",
                      "/sys/class/drm",
                      "有图形会话，但不能据此证明 DRM 或虚拟屏幕正常。")
    else:
        output = Node("显示输出", "bad" if drm == "disconnected" else "unknown",
                      "DRM 未连接" if drm == "disconnected" else "DRM 未知",
                      "需检查虚拟屏", "/sys/class/drm",
                      "没有可确认的图形输出，请查看菜单 1、2 的虚拟显示方案。")

    # Installed packages, configured default and actual services are separate
    # facts. Two active managers are ambiguous; an installed but inactive second
    # manager is not a second running desktop/login session.
    installed_dms = [name for name in ("gdm3", "lightdm")
                     if package(report, name).get("installed")]
    running_dms = [name for name in ("gdm3", "lightdm")
                   if display.get(name + "_service") == "active"]
    dm_names = {"gdm3": "GDM3", "lightdm": "LightDM"}
    if len(running_dms) > 1:
        dm_node = Node("登录管理器", "unknown", "GDM3 + LightDM",
                       "双服务运行 · 默认" + dm_names.get(actual_dm, "未识别"),
                       "/etc/X11/default-display-manager",
                       "两个登录管理器服务都报告运行中；可能争用同一 seat，"
                       "不能仅从运行状态判断哪个创建了当前会话。")
    elif len(installed_dms) > 1 and not running_dms and actual_dm not in installed_dms:
        dm_node = Node("登录管理器", "bad", "GDM3 + LightDM",
                       "均已安装 · 服务未运行 · 默认未识别",
                       "/etc/X11/default-display-manager",
                       "两个管理器软件包均已安装，但无服务运行；安装并不意味着创建了会话。")
    else:
        detected = running_dms[0] if running_dms else (
            actual_dm if actual_dm in installed_dms else
            (installed_dms[0] if installed_dms else ""))
        mismatch = bool(running_dms and actual_dm in dm_names
                        and detected != actual_dm)
        dm_installed = detected in installed_dms
        dm_running = bool(running_dms)
        dm_state = ("unknown" if mismatch or (dm_running and not dm_installed)
                    else ("ok" if dm_running else ("unknown" if graphical else "bad")))
        dm_detail = "v" + version(report, detected) if dm_installed else "版本未知"
        if mismatch:
            dm_detail += " · 默认" + dm_names[actual_dm]
        else:
            other = next((dm_names[name] for name in installed_dms if name != detected), "")
            if other:
                dm_detail += " · 另装" + other
        dm_node = Node("登录管理器", dm_state,
                       dm_names.get(detected, "未识别") +
                       (" · 运行" if dm_running else " · 未运行"),
                       dm_detail, "/etc/X11/default-display-manager",
                       ("默认配置与实际运行服务不一致，请核对 systemctl 和默认登录管理器。"
                        if mismatch else "安装了两个管理器不代表两个服务同时运行；"
                        "运行中的登录管理器也不证明用户桌面已建立。"))

    proto = "X11" if session_type == "x11" else ("Wayland" if session_type == "wayland" else "")
    if truncated:
        protocol = Node("图形协议", "unknown", "会话列表未完整", "图形协议待核实",
                        "loginctl list-sessions",
                        "系统会话数量超过只读检测上限，不能只取前面几个并断言协议。")
    elif multiple:
        types = ["X11" if entry["type"] == "x11" else "Wayland" for entry in graphical]
        unique_types = list(dict.fromkeys(types))
        p_value = "+".join(unique_types) if len(unique_types) > 1 else f"{unique_types[0]}×{len(types)}"
        protocol = Node("图形协议", "unknown", p_value, "多会话 · 待选择",
                        "loginctl list-sessions",
                        "多个图形用户会话可能使用不同图形协议；不能任选一个标绿。")
    elif proto:
        p_state = "ok" if proto == "Wayland" or has_socket else "unknown"
        p_value = proto
        p_detail = ("Xorg " + version(report, "xserver-xorg-core")) if proto == "X11" else "Wayland 会话"
        p_path = ("/tmp/.X11-unix/" + display.get("x11_socket_paths", ["X?"])[0]) if proto == "X11" and has_socket else (
            "/run/user/" + str(session.get("uid")) if proto == "Wayland" and session.get("uid") else "/run/user/…")
        p_explain = "已检测到唯一用户图形会话的协议；Xorg 是 X11 的常见服务器实现。"
    elif has_socket:
        p_state, p_value, p_detail, p_path = "unknown", "X11 待登录", "发现 X socket", "/tmp/.X11-unix"
        p_explain = "发现 X11 Socket，但尚无确认的活跃图形用户会话。"
    elif package(report, "xserver-xorg-core").get("installed"):
        p_state, p_value, p_detail, p_path = (
            "unknown", "Xorg 已安装", "无活动 X11 会话", "/usr/bin/Xorg")
        p_explain = ("已有 Xorg 软件包，但没有已确认的 X11/Wayland 图形会话。"
                     "DRM connected 只说明内核显示输出已连接，不代表 Xorg 正在运行。"
                     "请先安装桌面会话、启动 LightDM/GDM3，再从另一设备实际验证。")
    else:
        p_state, p_value, p_detail, p_path = "bad", "未建立", "未安装 Xorg / 无活动会话", "Xorg / Wayland"
        p_explain = "未检测到活跃 X11/Wayland 图形协议，不能推断桌面可被控制。"
    if not multiple and not truncated:
        protocol = Node("图形协议", p_state, p_value, p_detail, p_path, p_explain)

    if truncated:
        desk = Node("桌面环境", "unknown", "会话列表未完整", "桌面待核实",
                    "loginctl list-sessions", "会话扫描被截断，无法确认全部活动桌面。")
    elif multiple:
        desktops = [desktop_name(entry) or "未知桌面" for entry in graphical]
        unique_desktops = list(dict.fromkeys(desktops))
        label = ("+".join(unique_desktops) if len(unique_desktops) > 1
                 else f"{unique_desktops[0]}×{len(desktops)}")
        desk = Node("桌面环境", "unknown", label, "多用户会话",
                    "loginctl list-sessions",
                    "检测到多个已登录的图形桌面，不能仅凭软件包或会话顺序判断 RustDesk 目标。")
    else:
        depkg = desktop_package(selected)
        desk_exists = bool(package(report, depkg).get("installed")) if depkg else False
        d_state = "ok" if desktop and desk_exists else ("unknown" if selected else "bad")
        d_path = {"XFCE": "/usr/share/xsessions", "MATE": "/usr/share/xsessions",
                  "GNOME": "/usr/share/wayland-sessions", "KDE": "/usr/share/xsessions"}.get(selected, "—")
        desk = Node("桌面环境", d_state, selected or "未检测到",
                    ("v" + version(report, depkg)) if desk_exists else ("已装但未登录" if selected else "未安装"),
                    d_path, "软件包存在并不代表已启动；优先识别真实活跃的用户桌面。")

    if truncated:
        user_session = Node("图形会话", "unknown", "会话数量超限", "需人工确认",
                            "loginctl list-sessions",
                            "会话数量超过安全检查上限，不能声称没有其他图形会话。")
    elif multiple:
        parts = []
        for entry in graphical[:4]:
            sid_text = str(entry.get("id") or "?")[:24]
            label = desktop_name(entry) or "?"
            proto_text = "X11" if entry["type"] == "x11" else "Wayland"
            parts.append(f"{sid_text}:{label}/{proto_text}({entry['state']})")
        if len(graphical) > 4:
            parts.append(f"另有{len(graphical)-4}个")
        user_session = Node("图形会话", "unknown", f"多会话 {len(graphical)}",
                            " · ".join(parts), "loginctl list-sessions",
                            "存在多个在线/活跃图形用户会话；需指定 session ID、座席和 DISPLAY"
                            " 才能确认当前分辨率及 RustDesk 正在接管的会话。")
    elif session:
        sp = unique_display or signals.get("session_display", "")
        if not sp and real_x11_output:
            sp = x_display
        s_value = (sid + " · " if sid else "") + (sp or proto)
        s_state = "ok" if proto else "unknown"
        s_detail = res if real_x11_output else "分辨率待核实"
        s_path = "logind session " + sid if sid else "loginctl"
        s_explain = "logind 有活动用户会话；分辨率属于显示输出设置，非登录管理器。"
    else:
        s_state, s_value, s_detail, s_path = "bad", "用户未登录", "没有可用会话", "loginctl"
        s_explain = "缺少已确认的活动图形用户会话。GDM/LightDM 服务运行不代表用户已登录。"
    if not multiple and not truncated:
        user_session = Node("图形会话", s_state, s_value, s_detail, s_path, s_explain)

    if installed:
        r_state = "ok" if service == "active" else "bad"
        r_value = "运行中" if service == "active" else "服务未启动"
        r_detail = "v" + version(report, "rustdesk")
        if r_state == "ok" and (multiple or truncated):
            r_state = "unknown"
            r_value = "会话目标待确认"
        if r_state == "ok" and proto == "Wayland":
            requires = ["pipewire", "xdg-desktop-portal"]
            if desktop == "GNOME":
                requires.append("xdg-desktop-portal-gnome")
            missing = [name for name in requires if not package(report, name).get("installed")]
            if missing:
                r_state = "unknown"
                r_value = "依赖待补"
                r_detail = "缺 " + ", ".join(missing)
    else:
        r_state, r_value, r_detail = "bad", "未安装", "需要 RustDesk"
    rustdesk = Node("RustDesk", r_state, r_value, r_detail, "/usr/bin/rustdesk",
                    "安装及后台服务运行不代表屏幕捕获和远控认证已验证；"
                    "多个会话时需要另行验证实际捕获的座席和会话。")

    if got_id:
        id_state, id_value, id_detail = "ok" if r_state == "ok" else "unknown", got_id, "ID 已读出"
    else:
        id_state, id_value, id_detail = ("bad" if not installed else "unknown"), "未获取", "注册状态未知"
    identifier = Node("设备 ID", id_state, id_value, id_detail, "rustdesk --get-id",
                      "能读到 ID 不等于 ID 服务器已注册、远端可以连通或控制。")
    return [output, dm_node, protocol, desk, user_session, rustdesk, identifier]


def collect() -> list[Node]:
    report = status_json.collect()
    chosen = default_display_manager()
    resolution, output = xrandr_current()
    return build(report, {
        "manager": chosen,
        "drm": drm_status(),
        "resolution": resolution,
        "xrandr_output": output,
        "xrandr_display": os.getenv("DISPLAY", ""),
        "rustdesk_id": rustdesk_id() if package(report, "rustdesk").get("installed") else "",
    })


def text_width(value: str) -> int:
    return sum(0 if unicodedata.combining(ch) else
               (2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1)
               for ch in value)


def clipped(value: str, limit: int) -> str:
    value = str(value).replace("\n", " ")
    if text_width(value) <= limit:
        return value
    if limit <= 1:
        return "…"
    result = ""
    for ch in value:
        if text_width(result + ch) > limit - 1:
            break
        result += ch
    return result + "…"


def center(value: str, limit: int) -> str:
    value = clipped(value, limit)
    pad = max(0, limit - text_width(value))
    return " " * (pad // 2) + value + " " * (pad - pad // 2)


def color(value: str, state: str, enabled: bool) -> str:
    return ANSI.get(state, "") + value + RESET if enabled else value


def axis(nodes: list[Node], cell: int, enabled: bool) -> str:
    chunks = []
    for node in nodes:
        m = cell // 2
        dot = STATUS_MARKS[node.state]
        dot = color(dot, node.state, enabled)
        chunks.append("─" * m + dot + "─" * (cell - m - 1))
    return "  " + "".join(chunks)


def grid(nodes: list[Node], cell: int, enabled: bool) -> str:
    rows = [axis(nodes, cell, enabled)]
    for attr in ("name", "value", "detail", "path"):
        parts = []
        for node in nodes:
            value = getattr(node, attr)
            if attr == "value":
                value = STATUS_SIGNS[node.state] + " " + value
            text = center(value, cell)
            parts.append(color(text, node.state, enabled) if attr == "value" else text)
        rows.append("  " + "".join(parts))
    return "\n".join(rows)


def render(nodes: list[Node], cols: int = 80, enabled: bool = False, details: bool = False) -> str:
    cols = max(24, cols)
    lines = []
    if cols >= 107:
        cell = min(20, (cols - 2) // 7)
        lines.append(grid(nodes, cell, enabled))
    elif cols >= 67:
        cell = min(20, (cols - 2) // 4)
        lines.append(grid(nodes[:4], cell, enabled))
        lines.append("  ↓ 继续：会话 → RustDesk → 设备 ID")
        lines.append(grid(nodes[4:], cell, enabled))
    else:
        for idx, node in enumerate(nodes, 1):
            mark = color(STATUS_MARKS[node.state], node.state, enabled)
            value = clipped(node.value, max(3, cols - 18))
            label = center(node.name, 10)
            lines.append(f"  {mark} {idx}. {label} {value}")
            if idx != len(nodes):
                lines.append("  │")
    if cols < 55:
        lines.append("  ●正常 ○异常 ◆待查")
        lines.append("  远端控制另行实测")
    else:
        lines.append("  " + ("绿=本地通过 · 红=缺失/异常 · 黄=待核实" if enabled else
                              "●=本地通过  ○=缺失/异常  ◆=待核实"))
        lines.append("  本机检测不代表 RustDesk 远端画面已验证。")
    if details:
        lines.append("")
        for idx, node in enumerate(nodes, 1):
            lines.append(f"  {idx}. [{STATUS_SIGNS[node.state]}] {node.name}：{node.value} · {node.detail}")
            lines.append(f"     路径/检查：{node.path}")
            lines.append(f"     说明：{node.explanation}")
        lines.append("  提示：使用 sudo hdm 查看管理员权限能访问的全部配置状态。")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--width", type=int, default=shutil.get_terminal_size(fallback=(80, 24)).columns)
    parser.add_argument("--details", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    nodes = collect()
    if args.json:
        print(json.dumps([asdict(x) for x in nodes], ensure_ascii=False, indent=2))
    else:
        enabled = sys.stdout.isatty() and os.getenv("NO_COLOR") is None and os.getenv("TERM") != "dumb"
        print(render(nodes, args.width, enabled, args.details))


if __name__ == "__main__":
    main()
