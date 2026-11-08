#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
source "$ROOT/ui/actions_v2.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_installed() { return 1; }
rc=0
out=$(hdm_v2_protocol_select_wayland) || rc=$?
[[ $rc == 2 && $out == *'GNOME'* && $out == *'菜单 4'* ]]
hdm_installed() { return 0; }
hdm_v2_wayland_session_available() { return 1; }
rc=0
out=$(hdm_v2_protocol_select_wayland) || rc=$?
[[ $rc == 2 && $out == *'未找到 Wayland 桌面会话文件'* ]]
hdm_v2_wayland_session_available() { return 0; }
hdm_v2_default_dm() { printf 'lightdm\n'; }
hdm_v2_choose_dm() { printf 'CHOOSING %s\n' "$1"; }
out=$(hdm_v2_protocol_select_wayland)
[[ $out == *'CHOOSING gdm3'* ]]
hdm_v2_default_dm() { printf 'gdm3\n'; }
out=$(hdm_v2_protocol_select_wayland)
[[ $out == *'GDM3 已是默认'* && $out != *'CHOOSING'* ]]
echo 'PASS GNOME Wayland respects installed desktop, existing session and selected manager'
