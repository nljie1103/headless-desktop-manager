#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export HDM_ROOT=$ROOT HDM_LOG_DIR=/nonexistent HDM_STATE=/nonexistent
source "$ROOT/core/common.sh"
source "$ROOT/modules/desktop/session.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_show() { :; }
hdm_confirm() { return 0; }
hdm_session_candidates() {
  printf 'c2|ubuntu|xfce|x11|active\n'
  printf 'c3|another|gnome|wayland|online\n'
}
loginctl() {
  [[ $1 == show-session ]] || { echo "unexpected loginctl $*" >&2; return 99; }
  case "$4" in
    Type) if [[ $2 == c3 ]]; then printf 'tty\n'; else printf 'x11\n'; fi;;
    Class) printf 'user\n';;
    Name) printf 'ubuntu\n';;
    *) return 1;;
  esac
}
hdm_prompt() { printf -v "$2" '%s' "$CHOICE"; }
export HDM_DRY_RUN=1
CHOICE=0
output=$(hdm_session_terminate_graphical)
[[ $output == *'已取消'* ]]
CHOICE=c2
output=$(hdm_session_terminate_graphical)
[[ $output == *'[DRY RUN] loginctl terminate-session c2'* ]]
CHOICE=ssh22
rc=0
output=$(hdm_session_terminate_graphical) || rc=$?
[[ $rc -eq 2 && $output == *'不在已验证的图形用户列表'* ]]
CHOICE=c3
rc=0
output=$(hdm_session_terminate_graphical) || rc=$?
[[ $rc -eq 2 && $output == *'类型已变化'* ]]
# Incomplete scan must never offer destructive action.
hdm_session_candidates() { return 3; }
CHOICE=c2
rc=0
output=$(hdm_session_terminate_graphical) || rc=$?
[[ $rc -eq 2 && $output == *'拒绝结束会话'* ]]
# GNOME/Wayland cannot be silently forced into a LightDM X11 choice.
hdm_v2_default_dm() { printf 'gdm3\n'; }
rc=0
output=$(hdm_session_select_default) || rc=$?
[[ $rc -eq 2 && $output == *'不能直接把 DRM 切成 Wayland'* ]]
echo 'PASS graphical session IDs guarded, SSH excluded, incomplete scans fail-closed, protocol selection scoped'
