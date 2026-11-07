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
echo 'PASS GDM3 service state and real user session are independent'
