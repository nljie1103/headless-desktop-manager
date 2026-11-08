#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export HDM_ROOT="$ROOT"
source "$ROOT/core/common.sh"
source "$ROOT/modules/desktop/session.sh"
source "$ROOT/modules/display/display.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_show() { :; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_confirm() { return 0; }
hdm_v2_default_dm() { echo lightdm; }
hdm_installed() { [[ $1 == lightdm || $1 == lightdm-gtk-greeter || $1 == xserver-xorg-core ]]; }
hdm_session_has_x11_desktop() { return 0; }
hdm_v2_dm_service() { printf 'SERVICE_ACTION=%s\n' "$1"; }
hdm_service_state() { printf '%s\n' "$STATE"; }
export HDM_DRY_RUN=1
STATE=inactive
result=$(hdm_session_prepare_login)
[[ $result == *'SERVICE_ACTION=start'* && $result == *'[DRY RUN]'* ]]
[[ $result == *'输入密码'* && $result == *'不会开启免密码自动登录'* ]]
STATE=active
result=$(hdm_session_prepare_login)
[[ $result == *'登录界面服务已经运行'* && $result != *'SERVICE_ACTION'* ]]
STATE=inactive
hdm_session_has_x11_desktop() { return 1; }
rc=0
result=$(hdm_session_prepare_login) || rc=$?
[[ $rc == 2 && $result == *'缺少 X11 桌面会话文件'* ]]
hdm_session_has_x11_desktop() { return 0; }
hdm_session_candidates() { return 0; }
result=$(hdm_session_list_graphical)
[[ $result == *'已登录图形用户会话：0'* && $result == *'登录管理器未运行'* ]]
result=$(hdm_session_show_detail)
[[ $result == *'没有已登录的图形用户会话'* ]]
STATE=active
result=$(hdm_session_list_graphical)
[[ $result == *'登录管理器已运行'* && $result == *'输入密码'* ]]
hdm_env_drm_label() { echo '内核虚拟显示输出已连接'; }
hdm_env_drm_state() { echo connected; }
hdm_pkg_version() { echo installed; }
hdm_has() { return 1; }
STATE=inactive
result=$(hdm_display_status)
[[ $result == *'DRM/KMS：内核虚拟显示输出已连接'* ]]
[[ $result == *'LightDM：inactive'* ]]
[[ $result == *'Xorg（X11）：已安装'* ]]
[[ $result == *'已登录图形用户会话：0'* ]]
echo 'PASS login greeter lifecycle, no autologin, empty sessions and DRM-first display status'
