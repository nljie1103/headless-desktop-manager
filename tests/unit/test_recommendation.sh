#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_MEMINFO_PATH="$TMP/meminfo"
source "$ROOT/core/common.sh"
source "$ROOT/core/environment.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
hdm_env_desktop_kind() { printf 'none\n'; }
hdm_env_drm_state() { printf 'not-connected\n'; }
hdm_gnome_wayland_only() { return 0; }
printf 'MemTotal: %d kB\nMemAvailable: 1000000 kB\n' "$((2*1024*1024))" > "$TMP/meminfo"
[[ $(hdm_quick_desktop_choice none) == XFCE ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'xfce-pkg rustdesk-pkg' ]]
printf 'MemTotal: %d kB\nMemAvailable: 4000000 kB\n' "$((8*1024*1024))" > "$TMP/meminfo"
[[ $(hdm_quick_desktop_choice none) == GNOME ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'gnome-pkg wayland-deps rustdesk-pkg' ]]
hdm_env_desktop_kind() { printf 'GNOME\n'; }
[[ $(hdm_quick_desktop_choice GNOME) == GNOME ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'wayland-deps rustdesk-pkg' ]]
echo 'PASS server-size recommendations, existing desktop preserved'
