#!/usr/bin/env bash
set -uo pipefail
HDM_ENTRY_ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
# Only local installed scripts, no remote source, eval or arbitrary plugin execution.
for module in \
  core/common.sh core/backup.sh core/packages.sh core/downloader.sh \
  modules/display/display.sh modules/desktop/desktop.sh modules/rustdesk/rustdesk.sh \
  modules/updater/updater.sh modules/diagnostics/diagnostics.sh \
  modules/quick-install/quick-install.sh ui/actions.sh ui/menu.sh; do
  # shellcheck disable=SC1090
  source "$HDM_ENTRY_ROOT/$module"
done
hdm_init
case "${1:-}" in
  --help|-h) cat <<'HELP'
Headless Desktop Manager (HDM)
  sudo hdm                      Interactive menu
  hdm --version                  Print version
  hdm --menu-tree                Print every menu path
  hdm --self-test                Local non-destructive basic check
  sudo hdm --diagnose            Read-only system check
  hdm --status-json              Read-only machine-readable health report
  sudo hdm --confirm-display     Confirm new Xorg/GDM config, cancel recovery timer
  sudo hdm --rollback-pending    Apply pending config restoration (systemd recovery)
HELP
    exit 0;;
  --version) printf 'HDM %s\n' "$HDM_VERSION"; exit 0;;
  --menu-tree) hdm_menu_tree; exit 0;;
  --self-test) hdm_update_integrity && python3 "$HDM_ROOT/scripts/verify-menus.py"; exit $?;;
  --diagnose) hdm_diag_full; exit 0;;
  --status-json) hdm_diag_status_json; exit $?;;
  --confirm-display) hdm_recovery_confirm; exit $?;;
  --rollback-pending) hdm_recovery_rollback_pending; exit $?;;
  '') hdm_menu root; exit 0;;
  *) printf '未知参数：%s\n' "$1" >&2; exit 2;;
esac
