#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
source "$ROOT/core/common.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
hdm_root() { :; }
hdm_has() { [[ $1 == rustdesk ]] || command -v "$1" >/dev/null 2>&1; }
hdm_rustdesk_permissions_apply() { printf '%s %s\n' "$1" "$2" > "$TMP/auth"; }
rustdesk() { [[ $1 == --password && $2 == 'short' ]]; }
printf 'short\n' | hdm_rustdesk_password > "$TMP/output"
[[ $(cat "$TMP/auth") == 'auth N' ]]
[[ $(cat "$TMP/output") == *'密码（输入可见）'* ]]
[[ $(cat "$TMP/output") != *'YES'* ]]
# Empty input rejected; no arbitrary 12-character threshold.
if printf '\n' | hdm_rustdesk_password >/dev/null 2>&1; then exit 1; fi
echo 'PASS visible one-shot permanent password and unattended auth mode'
