#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
mkdir -p "$HDM_STATE" "$HDM_ETC" "$HDM_CACHE/downloads" "$HDM_LOG_DIR" "$TMP/stages"
source "$ROOT/core/common.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
# Fully mocked host operations: the test must not modify the real system.
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_quick_preflight() { :; }
hdm_danger() { :; }
hdm_diag_full() { :; }
hdm_quick_check() { [[ -e $TMP/stages/$1 ]]; }
hdm_quick_execute_step() {
  printf '%s\n' "$1" >> "$TMP/attempts"
  if [[ $1 == gnome-pkg && ! -e $TMP/failure-once ]]; then
    touch "$TMP/failure-once"
    return 9
  fi
  touch "$TMP/stages/$1"
}
# First run stops after a deliberately failed GNOME step.
if hdm_quick_install > "$TMP/first.log" 2>&1; then echo 'Expected failure'; exit 1; fi
[[ $(hdm_quick_recorded dummy-pkg) == done ]]
[[ $(hdm_quick_recorded gnome-pkg) == failed ]]
[[ $(cat "$TMP/attempts") == $'dummy-pkg\ngnome-pkg' ]]
# Second run resumes: first stage is re-verified, not installed again.
hdm_quick_install > "$TMP/second.log" 2>&1
[[ $(grep -c '^dummy-pkg$' "$TMP/attempts") == 1 ]]
[[ $(grep -c '^gnome-pkg$' "$TMP/attempts") == 2 ]]
for step in "${HDM_QUICK_STEPS[@]}"; do
  [[ $(hdm_quick_recorded "$step") == done ]]
done
# Ledger is never trusted without actual state: removing component forces reinstall.
rm "$TMP/stages/dummy-pkg"
hdm_quick_install > "$TMP/third.log" 2>&1
[[ $(grep -c '^dummy-pkg$' "$TMP/attempts") == 2 ]]
# Records reject unknown steps/status; these cannot be used as arbitrary file keys.
if hdm_quick_mark '../../etc/passwd' done; then exit 1; fi
if hdm_quick_mark gdm-x11 'enabled;rm -rf /'; then exit 1; fi
# Read-only CLI reports ledger and verified host state.
hdm_quick_status > "$TMP/status.out"
grep -q '完整 GNOME' "$TMP/status.out"
echo 'PASS quick install resume, step re-validation and safe ledger'
