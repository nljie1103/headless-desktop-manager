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
# Actual new routing uses a separate explicit target map; none of the 381 old
# action IDs are evaluated or inferred from the new menu number.
source "$ROOT/ui/menu.sh"
HDM_ROOT=$ROOT
[[ $(hdm_menu_action_target 8.5) == '10.8.7' ]]
[[ $(hdm_menu_action_target 6.4.1.1) == '7.1.1' ]]
[[ $(hdm_menu_action_target 7.1.1) == '7.8.1' ]]
[[ $(hdm_menu_action_target 8.2.2) == 'new:script-uninstall' ]]
[[ $(hdm_menu_action_target 2.1.2) == 'new:dm-install-lightdm' ]]
[[ $(hdm_menu_action_target 2.2.1) == 'new:dm-uninstall-preview-gdm' ]]
[[ $(hdm_menu_action_target 2.2.2) == 'new:dm-remove-gdm3' ]]
[[ $(hdm_menu_action_target 2.2.4) == 'new:dm-remove-lightdm' ]]
[[ $(hdm_menu_action_target 2.5.1) == 'new:dm-select-lightdm' ]]
[[ $(hdm_menu_action_target 4.2.2) == 'new:desktop-remove-gnome' ]]
[[ $(hdm_menu_action_target 4.2.3) == 'new:desktop-remove-xfce' ]]
[[ $(hdm_menu_action_target 1.2.1.4) == '2.8.4' ]]
[[ $(hdm_menu_label 1) == '显示输出管理' ]]
[[ $(hdm_menu_label 8) == 'HDM 脚本管理' ]]
# Every old tested action target remains accessible from the new mapping.
python3 "$ROOT/scripts/build-menus-v2.py" --check >/dev/null
python3 "$ROOT/scripts/audit-menu-actions.py" >/dev/null
echo 'PASS eight-stage dispatch map, script uninstall safety, preserved releases and explicit cancel'
