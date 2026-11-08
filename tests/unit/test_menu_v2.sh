#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-v2-menu-test.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_TEST_MODE=1
export HDM_UNINSTALL_TEST_BASE="$TMP/installed/hdm"
export HDM_UNINSTALL_TEST_COMMAND="$TMP/bin/hdm"
mkdir -p "$HDM_UNINSTALL_TEST_BASE/releases/v4.2.0" "$TMP/bin"
echo '4.2.0' > "$HDM_UNINSTALL_TEST_BASE/releases/v4.2.0/VERSION"
printf '#!/usr/bin/env bash\n' > "$HDM_UNINSTALL_TEST_BASE/releases/v4.2.0/hdm.sh"
ln -s "$HDM_UNINSTALL_TEST_BASE/releases/v4.2.0" "$HDM_UNINSTALL_TEST_BASE/current"
ln -s "$HDM_UNINSTALL_TEST_BASE/current/hdm.sh" "$HDM_UNINSTALL_TEST_COMMAND"
source "$ROOT/core/common.sh"
source "$ROOT/ui/actions_v2.sh"
# Safe stub permits test mode only; test creates all files under mktemp.
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_confirm() { return 1; }
preview=$(hdm_v2_uninstall_preview)
[[ $preview == *'保留'* && $preview == *'4.2.0'* ]]
status=0
hdm_v2_uninstall >/dev/null || status=$?
[[ $status == 2 && -L $HDM_UNINSTALL_TEST_COMMAND && -L $HDM_UNINSTALL_TEST_BASE/current ]]
hdm_confirm() { return 0; }
hdm_v2_uninstall > "$TMP/removed.log"
[[ ! -e $HDM_UNINSTALL_TEST_COMMAND && ! -L $HDM_UNINSTALL_TEST_BASE/current ]]
[[ -f $HDM_UNINSTALL_TEST_BASE/releases/v4.2.0/hdm.sh ]]
[[ ${HDM_UNINSTALLED:-0} == 1 ]]
# A different user's command or symlink must not be removed.
ln -s "$HDM_UNINSTALL_TEST_BASE/releases/v4.2.0" "$HDM_UNINSTALL_TEST_BASE/current"
echo other > "$TMP/other"
ln -s "$TMP/other" "$HDM_UNINSTALL_TEST_COMMAND"
status=0
hdm_v2_uninstall >/dev/null || status=$?
[[ $status == 2 && -L $HDM_UNINSTALL_TEST_COMMAND && -L $HDM_UNINSTALL_TEST_BASE/current ]]
# The compact menu exposes real service management and no legacy diagnosis maze.
source "$ROOT/ui/menu.sh"
HDM_ROOT=$ROOT
[[ $(hdm_menu_action_target 1.1) == 'new:quick-install' ]]
[[ $(hdm_menu_action_target 1.3) == 'new:session-prepare' ]]
[[ $(hdm_menu_action_target 2.1) == 'new:desktop-install-xfce' ]]
[[ $(hdm_menu_action_target 2.5) == 'new:desktop-remove-xfce' ]]
[[ $(hdm_menu_action_target 2.9.1) == 'new:session-list' ]]
[[ $(hdm_menu_action_target 2.9.2) == 'new:session-prepare' ]]
[[ $(hdm_menu_action_target 2.9.3) == 'new:session-detail' ]]
[[ $(hdm_menu_action_target 2.9.4) == 'new:session-terminate' ]]
[[ $(hdm_menu_action_target 2.9.5) == 'new:session-select' ]]
[[ $(hdm_menu_action_target 2.9.6) == 'new:protocol-status' ]]
[[ $(hdm_menu_action_target 2.9.7) == 'new:session-logs' ]]
[[ $(hdm_menu_action_target 3.1) == 'new:dm-install-lightdm' ]]
[[ $(hdm_menu_action_target 3.2) == 'new:dm-install-gdm3' ]]
[[ $(hdm_menu_action_target 3.3) == 'new:dm-start' ]]
[[ $(hdm_menu_action_target 3.4) == 'new:dm-stop' ]]
[[ $(hdm_menu_action_target 3.5) == 'new:dm-restart' ]]
[[ $(hdm_menu_action_target 3.6) == 'new:dm-autostart-on' ]]
[[ $(hdm_menu_action_target 3.7) == 'new:dm-autostart-off' ]]
[[ $(hdm_menu_action_target 3.9) == 'new:dm-remove-lightdm' ]]
[[ $(hdm_menu_action_target 3.10) == 'new:dm-remove-gdm3' ]]
[[ $(hdm_menu_action_target 3.11.1) == 'new:dm-select-lightdm' ]]
[[ $(hdm_menu_action_target 4.1) == 'new:rustdesk-install' ]]
[[ $(hdm_menu_action_target 4.2) == 'new:rustdesk-start' ]]
[[ $(hdm_menu_action_target 4.3) == 'new:rustdesk-stop' ]]
[[ $(hdm_menu_action_target 4.5) == 'new:rustdesk-autostart-on' ]]
[[ $(hdm_menu_action_target 4.6) == 'new:rustdesk-autostart-off' ]]
[[ $(hdm_menu_action_target 4.9) == '7.8.1' ]]
[[ $(hdm_menu_action_target 6.1) == 'new:script-update' ]]
[[ $(hdm_menu_action_target 6.2) == 'new:script-uninstall' ]]
[[ $(hdm_menu_action_target 6.4) == '10.8.7' ]]
hdm_update_install() { printf '%s:%s\n' "$1" "${HDM_QUICK_APPROVED:-0}"; }
[[ $(hdm_v2_update_release) == latest:1 ]]
[[ ${HDM_QUICK_APPROVED:-0} != 1 ]]
[[ $(hdm_menu_label 1) == '快速部署' ]]
[[ $(hdm_menu_label 6) == 'HDM 管理' ]]
# Service actions must resolve selected DM and never touch live systemd in dry-run.
hdm_v2_default_dm() { echo lightdm; }
hdm_installed() { [[ $1 == lightdm || $1 == xfce4-session || $1 == rustdesk ]]; }
hdm_has() { [[ $1 == systemctl ]]; }
hdm_confirm() { return 0; }
hdm_service_state() { echo inactive; }
export HDM_DRY_RUN=1
[[ $(hdm_v2_dm_service start) == *'[DRY RUN] systemctl start lightdm'* ]]
[[ $(hdm_v2_dm_service enable) == *'[DRY RUN] systemctl enable lightdm'* ]]
[[ $(hdm_v2_dm_service stop) == *'[DRY RUN] systemctl stop lightdm'* ]]
[[ $(hdm_v2_dm_service disable) == *'[DRY RUN] systemctl disable lightdm'* ]]
[[ $(hdm_v2_rustdesk_service start) == *'[DRY RUN] systemctl start rustdesk'* ]]
[[ $(hdm_v2_rustdesk_service stop) == *'[DRY RUN] systemctl stop rustdesk'* ]]
[[ $(hdm_v2_rustdesk_service enable) == *'[DRY RUN] systemctl enable rustdesk'* ]]
unset HDM_DRY_RUN
# Legacy actions remain in their original dispatch; the new menu only lists useful tasks.
python3 "$ROOT/scripts/build-menus-v2.py" --check >/dev/null
python3 "$ROOT/scripts/audit-menu-actions.py" >/dev/null
echo 'PASS task-first dispatch, service controls, script uninstall safety'
