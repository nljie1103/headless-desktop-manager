#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
source "$ROOT/core/common.sh"
source "$ROOT/core/environment.sh"
source "$ROOT/core/packages.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
source "$ROOT/modules/desktop/desktop.sh"

hdm_ubuntu_wayland_release 26.04
hdm_ubuntu_wayland_release 26.10
hdm_ubuntu_wayland_release 25.10
if hdm_ubuntu_wayland_release 24.04; then echo 'Ubuntu 24.04 must stay X11-capable'; exit 1; fi
if hdm_ubuntu_wayland_release 25.04; then exit 1; fi

hdm_ubuntu_source_render resolute arm64 > "$TMP/apt.sources"
grep -q 'URIs: https://ports.ubuntu.com/ubuntu-ports' "$TMP/apt.sources"
grep -q 'Suites: resolute resolute-updates' "$TMP/apt.sources"
grep -q 'Suites: resolute-security' "$TMP/apt.sources"
if grep -q noble "$TMP/apt.sources"; then exit 1; fi
hdm_ubuntu_source_render stonking arm64 > "$TMP/apt26.10.sources"
grep -q 'Suites: stonking stonking-updates' "$TMP/apt26.10.sources"
hdm_ubuntu_source_render noble amd64 > "$TMP/apt24.sources"
grep -q 'URIs: https://archive.ubuntu.com/ubuntu' "$TMP/apt24.sources"
if hdm_ubuntu_source_render invalid 'aarch64;rm'; then exit 1; fi

# Simulate a modern Ubuntu platform without touching /etc/os-release or any service.
hdm_env_desktop_kind() { printf "none\n"; }
hdm_env_drm_state() { printf "not-connected\n"; }
hdm_env_report() { :; }
hdm_gnome_wayland_only() { return 0; }
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
hdm_quick_plan > "$TMP/plan"
grep -q 'XFCE + LightDM / X11' "$TMP/plan"
if grep -q 'GDM3 使用 X11' "$TMP/plan"; then exit 1; fi
grep -q 'Xorg Dummy' "$TMP/plan"
# Defensive GDM3 X11 helper refuses before writing any settings.
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_warn() { :; }
if hdm_gdm_x11; then echo 'GDM X11 must be refused for GNOME 50'; exit 1; fi

# The 24.04 route preserves the older 5-step installer.
hdm_gnome_wayland_only() { return 1; }
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11' ]]

echo 'PASS Ubuntu 26 ARM64 sources, XFCE/X11 recommendation and safe GNOME Wayland split'
