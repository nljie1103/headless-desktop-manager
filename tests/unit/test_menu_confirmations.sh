#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
export HDM_ROOT=$ROOT HDM_DRY_RUN=1
source "$ROOT/core/common.sh"
source "$ROOT/core/packages.sh"
source "$ROOT/ui/actions_v2.sh"
source "$ROOT/ui/menu.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_info() { :; }
hdm_warn() { printf 'WARN %s\n' "$*"; }
hdm_type() { echo apt; }
hdm_apt_call() { printf 'APT %s\n' "$*"; }
hdm_v2_default_dm() { echo lightdm; }
hdm_service_state() { echo inactive; }
hdm_installed() { [[ $1 == lightdm || $1 == rustdesk || $1 == xfce4-session ]]; }
hdm_has() { [[ $1 == systemctl ]]; }
hdm_confirm() { return 2; }
output=$(hdm_menu_execute 3.4)
[[ $output == *'APT update'* && $output == *'APT install -y'* ]]
output=$(hdm_menu_execute 2.8)
[[ $output == *'APT update'* && $output == *'--only-upgrade lightdm'* ]]
output=$(hdm_menu_execute 2.7)
[[ $output == *'[DRY RUN] systemctl disable lightdm'* ]]
output=$(hdm_menu_execute 6.6)
[[ $output == *'[DRY RUN] systemctl disable rustdesk'* ]]
rc=0
output=$(hdm_menu_execute 2.4) || rc=$?
[[ $rc != 0 && $output == *'已取消'* ]]
rc=0
output=$(hdm_menu_execute 6.3) || rc=$?
[[ $rc != 0 && $output == *'已取消'* ]]
rc=0
output=$(hdm_pkg_install xfce4) || rc=$?
[[ $rc != 0 && $output == *'用户取消安装'* ]]
echo 'PASS no repeat y for menu, destructive service actions still guard'
