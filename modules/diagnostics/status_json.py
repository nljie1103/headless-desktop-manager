#!/usr/bin/env python3
"""Read-only sanitized HDM runtime health report. No passwords or config body."""
from __future__ import annotations
import json
import os
import pathlib
import platform
from datetime import datetime, timezone
import stat
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parents[2]

def run(*args, timeout=5):
    try:
        p = subprocess.run(args, check=False, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, PermissionError):
        return 127, ""


def installed(package):
    code, out = run('dpkg-query', '-W', '-f=${Status}|${Version}', package)
    if code == 0 and out.startswith('install ok installed|'):
        return {'installed': True, 'version': out.split('|', 1)[1]}
    return {'installed': False, 'version': None}


def service(name):
    code, out = run('systemctl', 'is-active', name)
    return out if code == 0 else (out or 'unknown')


def os_release():
    info = {}
    try:
        for line in pathlib.Path('/etc/os-release').read_text().splitlines():
            if '=' in line and not line.startswith('#'):
                k, v = line.split('=', 1)
                if k in {'ID', 'VERSION_ID', 'PRETTY_NAME'}:
                    info[k.lower()] = v.strip().strip('"')
    except OSError:
        pass
    return info


def sessions():
    """Inspect logind sessions without counting SSH/TTY as graphical desktops.

    A host can have dozens of SSH connections but zero graphical sessions.
    The cap is on actual logind records scanned (not on the first 24 rows).
    """
    code, raw = run('loginctl', 'list-sessions', '--no-legend', '--no-pager', timeout=6)
    if code != 0:
        return [], True  # retrieval failed; do not claim 'no sessions'
    identifiers = []
    for line in raw.splitlines():
        fields = line.split()
        if not fields:
            continue
        sid = fields[0]
        if len(sid) <= 48 and all(c.isalnum() or c in '-_' for c in sid):
            identifiers.append(sid)
    # 256 logind records is more than enough for ordinary servers. If the
    # bounded read is incomplete, surface uncertainty instead of a false "none".
    truncated = len(identifiers) > 256
    identifiers = identifiers[:256]

    def inspect(sid):
        code, details = run(
            'loginctl', 'show-session', sid, '-p', 'Type', '-p', 'Desktop',
            '-p', 'State', '-p', 'Class', '-p', 'Name', '-p', 'Remote', timeout=2)
        if code != 0:
            return None
        data = dict(p.split('=', 1) for p in details.splitlines() if '=' in p)
        if data.get('Type') not in ('x11', 'wayland') or data.get('Class') != 'user':
            return {}  # SSH/TTY, greeters and background managers are not user desktops
        return {
            'id': sid, 'type': data['Type'], 'desktop': data.get('Desktop', ''),
            'state': data.get('State', ''), 'class': data['Class'],
            'name': data.get('Name', ''), 'remote': data.get('Remote', ''),
        }

    result = []
    # Bounded concurrency avoids sequentially launching 40-100 processes
    # when a server has many SSH logins.
    with ThreadPoolExecutor(max_workers=8) as pool:
        for entry in pool.map(inspect, identifiers):
            if entry is None:
                truncated = True  # a live session disappeared or could not be read
            elif entry:
                result.append(entry)
    return result, truncated


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")

def x11_sockets():
    base = pathlib.Path("/tmp/.X11-unix")
    try:
        return sorted(p.name for p in base.iterdir() if p.name.startswith("X")
                      and p.name[1:].isdigit() and stat.S_ISSOCK(p.stat().st_mode))[:15]
    except (OSError, PermissionError):
        return []

def gdm_x11_enabled(lines):
    section = ""
    selected = None
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].lower()
            continue
        if section == "daemon" and "=" in line:
            key, value = line.split("=", 1)
            if key.strip().lower() == "waylandenable":
                selected = value.split("#", 1)[0].split(";", 1)[0].strip().lower()
    return selected == "false"

def rollback_marker_state(base: str | pathlib.Path) -> bool | None:
    """Missing marker is False; inaccessible root-only state is unknown."""
    try:
        return (pathlib.Path(base) / 'pending-rollback').is_file()
    except OSError:
        return None


def collect():
    try:
        version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
    except OSError:
        version = 'unknown'
    vdisplay = pathlib.Path('/etc/X11/xorg.conf.d/20-hdm-dummy.conf').is_file()
    gdmfile = pathlib.Path('/etc/gdm3/custom.conf')
    try:
        lines = gdmfile.read_text().splitlines()
        x11configured = gdm_x11_enabled(lines)
    except OSError:
        x11configured = False
    pkgs = {k: installed(k) for k in ('ubuntu-desktop','ubuntu-desktop-minimal','gnome-shell','gdm3',
                                    'xserver-xorg-video-dummy','xserver-xorg-core','xvfb','rustdesk','lightdm',
                                    'lightdm-gtk-greeter','xfce4','xfce4-session','mate-session-manager',
                                    'pipewire','xdg-desktop-portal','xdg-desktop-portal-gnome')}
    ss, sessions_truncated = sessions()
    # GDM greeter and user desktop are distinct; do not claim a working GNOME session from gdm3 alone.
    gnome_x11 = any(s['type'] == 'x11' and (s['desktop'].lower() in ('gnome','ubuntu','ubuntu-xorg') or 'gnome' in s['desktop'].lower()) and s['state'] == 'active' and s['class'] == 'user' for s in ss)
    gnome_wayland = any(s['type'] == 'wayland' and (s['desktop'].lower() in ('gnome','ubuntu') or 'gnome' in s['desktop'].lower()) and s['state'] == 'active' and s['class'] == 'user' for s in ss)
    report = {
        'schema': 1,
        'hdm_version': version,
        'system': {**os_release(), 'architecture': platform.machine()},
        'packages': pkgs,
        'display': {
            'hdm_dummy_config_present': vdisplay,
            'gdm_x11_config_present': x11configured,
            'gdm3_service': service('gdm3'),
            'lightdm_service': service('lightdm'),
            'xvfb_service': service('hdm-xvfb'),
            'x11_socket_present': bool(x11_sockets()),
            'x11_socket_paths': x11_sockets(),
        },
        'sessions': ss,
        'sessions_truncated': sessions_truncated,
        'gnome': {'active_gnome_x11_user_session_detected': gnome_x11,
                  'active_gnome_wayland_user_session_detected': gnome_wayland,
                  'remote_picture_captured': 'not_tested'},
        'rustdesk': {'service': service('rustdesk'), 'external_connection': 'not_tested',
                     'authentication': 'not_tested'},
        'rollback_pending': rollback_marker_state(os.environ.get('HDM_STATE', '/var/lib/hdm')),
        'warnings': [
            'Package and service detection does not prove desktop capture or unattended remote access.',
            'Verify the actual desktop screen, RustDesk authentication and reboot from another machine.',
        ],
    }
    return report

def main():
    json.dump(collect(), sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')

if __name__ == '__main__':
    main()
