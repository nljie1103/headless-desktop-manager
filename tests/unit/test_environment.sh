#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
export HDM_PROBE_DRM_ROOT="$TMP/drm"
mkdir -p "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1" "$HDM_PROBE_DRM_ROOT/card0-Virtual-1"
source "$ROOT/core/common.sh"
source "$ROOT/core/environment.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
# Real status results are read from fake sysfs, no OS changes made.
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status"
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == not-connected ]]
printf 'connected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == connected ]]
rm "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status" "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == unknown ]]
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status"
# Mock desktop packages: model the four presence combinations.
DESKTOP=none
hdm_env_desktop_kind() { printf '%s\n' "$DESKTOP"; }
hdm_gnome_wayland_only() { return 1; }
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11' ]]
printf 'connected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'gnome-pkg rustdesk-pkg' ]]
DESKTOP=GNOME
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg rustdesk-pkg dummy-config gdm-x11' ]]
DESKTOP=XFCE
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
# Modern GNOME has no GDM/X11 forcing; packages alone do not claim a display.
hdm_gnome_wayland_only() { return 0; }
DESKTOP=none
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'gnome-pkg wayland-deps rustdesk-pkg' ]]
DESKTOP=XFCE
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
# No side-effects from read-only preflight and permission diagnostics.
output=$(bash "$ROOT/hdm.sh" --preflight)
[[ $output == *'只读安装前检测'* && $output == *'推荐操作'* ]]
output=$(bash "$ROOT/hdm.sh" --rustdesk-permissions)
[[ $output == *'只读权限诊断'* && $output == *'Polkit'* ]]
for name in etc state cache log; do [[ ! -e $TMP/$name ]]; done
# Main menu displays detection summary immediately, without modifying system.
output=$(printf '0\n' | bash "$ROOT/hdm.sh")
[[ $output == *'显示输出'* && $output == *'建议：'* ]]
echo 'PASS environmental four-way preflight, conservative detection and RustDesk permissions'
