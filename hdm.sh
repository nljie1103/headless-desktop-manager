#!/usr/bin/env bash
set -uo pipefail
HDM_ENTRY_ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
# Only local installed scripts, no remote source, eval or arbitrary plugin execution.
for module in \
  core/common.sh core/environment.sh core/operation.sh core/backup.sh core/packages.sh core/downloader.sh \
  modules/display/display.sh modules/desktop/desktop.sh modules/rustdesk/rustdesk.sh \
  modules/updater/updater.sh modules/diagnostics/diagnostics.sh \
  modules/quick-install/quick-install.sh ui/actions.sh ui/menu.sh; do
  # shellcheck disable=SC1090
  source "$HDM_ENTRY_ROOT/$module"
done
# Diagnostic and informational operations must be read-only, even when run as root.
case "${1:-}" in
  --help|-h|--version|--menu-tree|--self-test|--diagnose|--doctor|--doctor-json|--status-json|--quick-status|--preflight|--rustdesk-permissions|--check-update)
    hdm_init readonly ;;
  *) hdm_init ;;
esac
case "${1:-}" in
  --help|-h) cat <<'HELP'
Headless Desktop Manager (HDM)
  sudo hdm                      Interactive menu
  hdm --version                  Print version
  hdm --menu-tree                Print every menu path
  hdm --self-test                Local non-destructive basic check
  sudo hdm --diagnose            Read-only system check
  hdm --doctor                   Chinese read-only actionable diagnosis
  hdm --preflight                Detect installed desktop and usable display outputs
  hdm --rustdesk-permissions     Read-only privileged settings / service diagnosis
  hdm --doctor-json              Sanitized diagnosis JSON
  sudo hdm --quick-status        Read-only resumable install progress
  sudo hdm --quick-resume        Resume missing/failed install steps (confirms safety)
  hdm --status-json              Read-only machine-readable health report
  hdm --check-update             Check GitHub Releases and main preview branch
  sudo hdm --update-main         Update manager from pinned GitHub main commit
  sudo hdm --confirm-display     Confirm new Xorg/GDM config, cancel recovery timer
  sudo hdm --rollback-pending    Apply pending config restoration (systemd recovery)
HELP
    exit 0;;
  --version) printf 'HDM %s\n' "$HDM_VERSION"; exit 0;;
  --menu-tree) hdm_menu_tree; exit 0;;
  --self-test) hdm_update_integrity && python3 "$HDM_ROOT/scripts/verify-menus.py"; exit $?;;
  --diagnose) hdm_diag_full; exit 0;;
  --preflight) hdm_env_report; exit $?;;
  --rustdesk-permissions) hdm_rustdesk_permission_report; exit $?;;
  --doctor) hdm_diag_doctor; exit $?;;
  --doctor-json) hdm_diag_doctor_json; exit $?;;
  --quick-status) hdm_quick_status; exit 0;;
  --quick-resume) hdm_quick_install; exit $?;;
  --status-json) hdm_diag_status_json; exit $?;;
  --check-update) hdm_update_check; exit $?;;
  --update-preview|--update-main) hdm_update_preview_install; exit $?;;
  --confirm-display) hdm_recovery_confirm; exit $?;;
  --rollback-pending) hdm_recovery_rollback_pending; exit $?;;
  '') hdm_menu root; exit 0;;
  *) printf '未知参数：%s\n' "$1" >&2; exit 2;;
esac
