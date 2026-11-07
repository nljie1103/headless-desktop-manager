#!/usr/bin/env python3
"""Read-only diagnostics for the recommended Ubuntu GNOME + Dummy + RustDesk path.

No private RustDesk config, secrets, user names, device IDs or raw logs are printed.
This cannot verify external image capture: that result is always manual/not-tested.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import status_json


def finding(code: str, level: str, title: str, note: str, action: str = '') -> dict:
    return {'code': code, 'level': level, 'title': title, 'detail': note, 'next_action': action}


def inspect(report: dict) -> list[dict]:
    """Pure function, allows deterministic tests with synthetic host states."""
    checks = []
    system = report.get('system', {})
    packages = report.get('packages', {})
    display = report.get('display', {})
    rustdesk = report.get('rustdesk', {})
    gnome = report.get('gnome', {})

    platform_ok = system.get('id') == 'ubuntu' and system.get('version_id') == '24.04' and system.get('architecture') == 'x86_64'
    checks.append(finding('platform', 'ok' if platform_ok else 'unsupported', '系统兼容性',
        '目标为 Ubuntu 24.04 x86_64。' if platform_ok else '当前系统不是已支持的写入目标；建议只执行只读诊断。'))

    dummy = packages.get('xserver-xorg-video-dummy', {}).get('installed')
    checks.append(finding('dummy_package', 'ok' if dummy else 'action', 'Xorg Dummy 驱动',
        '系统包已安装（尚需检查实际加载）。' if dummy else '未检测到驱动软件包。', '菜单 1.1.1' if not dummy else ''))
    conf = display.get('hdm_dummy_config_present')
    checks.append(finding('dummy_config', 'ok' if conf else 'action', '虚拟屏幕配置',
        'HDM 配置存在；不代表 Xorg 已使用。' if conf else '未检测到 HDM 的 Xorg Dummy 配置。', '菜单 1.1.1' if not conf else ''))

    full_gnome = packages.get('ubuntu-desktop', {}).get('installed')
    gnome_shell = packages.get('gnome-shell', {}).get('installed')
    checks.append(finding('gnome_package', 'ok' if full_gnome and gnome_shell else 'action', '完整 GNOME',
        '完整桌面软件包已安装。' if full_gnome and gnome_shell else '完整 GNOME 软件包缺失或不完整。',
        '菜单 3.1.1' if not (full_gnome and gnome_shell) else ''))

    gdm = display.get('gdm3_service')
    checks.append(finding('gdm_service', 'ok' if gdm == 'active' else 'action', 'GDM3 服务',
        f'服务状态：{gdm or "unknown"}。' + ('' if gdm == 'active' else '请检查服务日志。'),
        '菜单 10.3.7' if gdm != 'active' else ''))
    gdm_x11 = display.get('gdm_x11_config_present')
    checks.append(finding('gdm_x11', 'ok' if gdm_x11 else 'action', 'GDM3 X11 设置',
        '已在 [daemon] 中设置 WaylandEnable=false。' if gdm_x11 else '尚未检测到有效的 X11 强制设置。',
        '菜单 3.1.5' if not gdm_x11 else ''))

    sockets = display.get('x11_socket_paths', [])
    checks.append(finding('x11_sockets', 'ok' if sockets else 'warning', 'X11 显示套接字',
        '检测到：' + ', '.join(sockets[:4]) if sockets else '未检测到本地 X11 套接字；可能尚未启动图形会话。',
        '菜单 10.2.2' if not sockets else ''))
    x11_session = gnome.get('active_gnome_x11_user_session_detected')
    checks.append(finding('gnome_session', 'ok' if x11_session else 'warning', 'GNOME X11 用户会话',
        '检测到活跃 GNOME X11 用户会话。' if x11_session else '未确认活跃 GNOME X11 用户会话；纯登录界面可能仍存在。',
        '菜单 10.3.3' if not x11_session else ''))

    client = packages.get('rustdesk', {}).get('installed')
    checks.append(finding('rustdesk_package', 'ok' if client else 'action', 'RustDesk 客户端',
        '软件包已安装。' if client else '未检测到 RustDesk 软件包。', '菜单 5' if not client else ''))
    active = rustdesk.get('service') == 'active'
    checks.append(finding('rustdesk_service', 'ok' if active else 'action', 'RustDesk 服务',
        '服务正在运行（不代表已注册或可控）。' if active else '服务未运行或状态不可用。',
        '菜单 10.4.8' if not active else ''))

    if report.get('rollback_pending'):
        checks.append(finding('rollback', 'warning', '显示配置待确认',
            '存在回滚计时器；需要在真实外部图像测试后决定确认或回滚。',
            'sudo hdm --confirm-display 或 sudo hdm --rollback-pending'))
    else:
        checks.append(finding('rollback', 'ok', '安全回滚状态', '未发现待确认的回滚标记。'))

    checks.append(finding('remote_validation', 'manual', '外部远程连接与重启',
        '无法从本地自动判断画面、鼠标、密码与重启后无人值守访问是否有效。',
        '从另一台电脑连接 RustDesk，并进行冷启动回归测试'))
    return checks


def build() -> dict:
    report = status_json.collect()
    findings = inspect(report)
    return {
        'schema': 1,
        'hdm_version': report['hdm_version'],
        'generated_at': status_json.utc_now(),
        'scope': 'ubuntu-24.04-x86_64-gnome-dummy-rustdesk',
        'summary': {
            'ok': sum(x['level'] == 'ok' for x in findings),
            'action': sum(x['level'] == 'action' for x in findings),
            'warning': sum(x['level'] == 'warning' for x in findings),
            'manual': sum(x['level'] == 'manual' for x in findings),
            'unsupported': sum(x['level'] == 'unsupported' for x in findings),
        },
        'findings': findings,
        'actual_remote_connection_verified': False,
    }


def human(result: dict) -> str:
    symbols = {'ok':'✓', 'action':'×', 'warning':'!', 'manual':'?', 'unsupported':'-'}
    lines = [f"HDM v{result['hdm_version']} · 无显示器 GNOME / RustDesk 诊断（只读）", '=' * 66]
    for item in result['findings']:
        lines.append(f"[{symbols.get(item['level'], '?')}] {item['title']}：{item['detail']}")
        if item['next_action']:
            lines.append(f"    建议：{item['next_action']}")
    summary = result['summary']
    lines.extend(['-' * 66,
        f"通过 {summary['ok']} · 需处理 {summary['action']} · 警告 {summary['warning']} · 人工验证 {summary['manual']}",
        '结果仅为服务器本地诊断，不能代替远端图形连接测试。'])
    return '\n'.join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--json', action='store_true', help='machine-readable sanitized output')
    args = parser.parse_args()
    result = build()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(human(result))


if __name__ == '__main__':
    main()
