#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_MEMINFO_PATH="$TMP/meminfo"
source "$ROOT/core/common.sh"
source "$ROOT/core/environment.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
source "$ROOT/modules/desktop/desktop.sh"
hdm_env_desktop_kind() { printf 'none\n'; }
hdm_env_drm_state() { printf 'not-connected\n'; }
hdm_gnome_wayland_only() { return 0; }
printf 'MemTotal: %d kB\nMemAvailable: 1000000 kB\n' "$((2*1024*1024))" > "$TMP/meminfo"
[[ $(hdm_quick_desktop_choice none) == XFCE ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
printf 'MemTotal: %d kB\nMemAvailable: 4000000 kB\n' "$((8*1024*1024))" > "$TMP/meminfo"
[[ $(hdm_quick_desktop_choice none) == XFCE ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
hdm_env_desktop_kind() { printf 'GNOME\n'; }
[[ $(hdm_quick_desktop_choice GNOME) == XFCE ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
hdm_env_desktop_kind() { printf 'MATE\n'; }
[[ $(hdm_quick_desktop_choice MATE) == MATE ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
hdm_gnome_wayland_only() { return 1; }
hdm_env_desktop_kind() { printf 'none\n'; }
[[ $(hdm_quick_desktop_choice none) == GNOME ]]
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11' ]]
# Test the actual XFCE package plan without installing or switching any service.
hdm_pkg_install() { printf '%s\n' "$*"; }
install_plan=$(hdm_desktop_install_light xfce standard)
[[ $install_plan == *'xfce4 xfce4-goodies xorg lightdm lightdm-gtk-greeter'* ]]
hdm_installed() { [[ $1 == lightdm || $1 == xfce4-session ]]; }
hdm_service_state() { printf 'inactive\n'; }
guide=$(hdm_desktop_login_manager_guide)
[[ $guide == *'sudo dpkg-reconfigure lightdm'* ]]
[[ $guide == *'HDM 不会代替用户切换显示管理器'* ]]
echo 'PASS protocol-based XFCE/X11 plans, manual LightDM guide and legacy GNOME path'
