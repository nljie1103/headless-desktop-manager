#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export HDM_STATE=/nonexistent HDM_LOG_DIR=/nonexistent
source "$ROOT/core/common.sh"
source "$ROOT/modules/desktop/session.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_installed() { return 0; }
hdm_env_drm_state() { printf 'connected\n'; }
hdm_env_drm_short() { printf '已连接'; }
hdm_env_desktop_kind() { printf 'GNOME'; }
hdm_env_active_session() { printf 'none\n'; }
hdm_service_state() { printf 'active\n'; }
hdm_session_report() { printf 'GDM3 active but user session none\n'; }
# Service already active is not equivalent to a usable graphical session.
rc=0; output=$(hdm_session_start_gdm) || rc=$?
[[ $rc -eq 3 && $output == *'部分完成'* ]]
rc=0; output=$(hdm_session_repair) || rc=$?
[[ $rc -eq 3 && $output == *'none'* ]]
hdm_env_active_session() { printf 'wayland\n'; }
output=$(hdm_session_start_gdm)
[[ $output == *'无需重启'* ]]
# Reporting must not claim GNOME is installed on an XFCE-only host.
source "$ROOT/modules/desktop/session.sh"
hdm_installed() { return 1; }
hdm_env_desktop_kind() { printf 'XFCE'; }
hdm_service_state() { printf 'inactive'; }
report=$(hdm_session_report)
[[ $report == *'[缺失] 未安装 GDM3'* ]]
[[ $report == *'当前桌面环境为 XFCE'* ]]
[[ $report != *'GNOME 软件包已安装'* ]]
hdm_installed() { return 0; }
report=$(hdm_session_report)
[[ $report == *'[阻断] GDM3 已安装但未运行'* ]]
echo 'PASS GDM3 package/service/session state and XFCE-only reporting'
