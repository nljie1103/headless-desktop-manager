#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log" \
       HDM_RUSTDESK_CONFIG_ROOT="$TMP/root/RustDesk2.toml" SUDO_USER=ubuntu
mkdir -p "$HDM_STATE" "$HDM_ETC" "$HDM_LOG_DIR" "$TMP/root" "$TMP/user"
source "$ROOT/core/common.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
hdm_root() { :; }
hdm_has() { [[ $1 == rustdesk ]] || command -v "$1" >/dev/null 2>&1; }
hdm_service_state() { echo active; }
hdm_confirm() { return 0; }
hdm_rustdesk_login_profile() { printf '%s\t%s\t%s\n' "$TMP/user/RustDesk2.toml" "$(id -u)" "$(id -g)"; }
HDM_LAST_SNAPSHOT=''
hdm_snapshot_create() {
  HDM_LAST_SNAPSHOT=stub
  : > "$TMP/paths"
  local path count=0
  for path in "$@"; do
    count=$((count+1))
    printf '%s\t%s\n' "$path" "$count" >> "$TMP/paths"
    if [[ -f $path ]]; then cp -p "$path" "$TMP/bak-$count"; else rm -f "$TMP/bak-$count"; fi
  done
}
hdm_snapshot_restore() {
  local path count
  while IFS=$'\t' read -r path count; do
    if [[ -f $TMP/bak-$count ]]; then cp -p "$TMP/bak-$count" "$path"; else rm -f "$path"; fi
  done < "$TMP/paths"
}
FAIL_START=0
systemctl() {
  case "$1" in
    stop) return 0;;
    start) [[ $FAIL_START == 0 ]];;
    *) return 1;;
  esac
}
printf '[options]\nprevious-option = "preserve"\n' > "$TMP/root/RustDesk2.toml"
cp "$TMP/root/RustDesk2.toml" "$TMP/user/RustDesk2.toml"
hdm_rustdesk_permissions_apply custom N > "$TMP/normal.log"
python3 "$ROOT/scripts/rustdesk_permissions.py" verify "$TMP/root/RustDesk2.toml" --mode custom --remote N > /dev/null
python3 "$ROOT/scripts/rustdesk_permissions.py" verify "$TMP/user/RustDesk2.toml" --mode custom --remote N > /dev/null
hdm_rustdesk_permissions_apply toggle N enable-keyboard N > "$TMP/keyboard.log"
python3 "$ROOT/scripts/rustdesk_permissions.py" verify "$TMP/root/RustDesk2.toml" --mode toggle --flag enable-keyboard --value N >/dev/null
hdm_rustdesk_permissions_apply toggle N enable-clipboard Y > "$TMP/clipboard.log"
python3 "$ROOT/scripts/rustdesk_permissions.py" verify "$TMP/user/RustDesk2.toml" --mode toggle --flag enable-keyboard --value N >/dev/null
hdm_rustdesk_permissions_apply custom Y > "$TMP/enable.log"
python3 "$ROOT/scripts/rustdesk_permissions.py" verify "$TMP/user/RustDesk2.toml" --mode custom --remote Y > /dev/null
cp "$TMP/root/RustDesk2.toml" "$TMP/known-root"
cp "$TMP/user/RustDesk2.toml" "$TMP/known-user"
FAIL_START=1
if hdm_rustdesk_permissions_apply view N > "$TMP/failure.log" 2>&1; then
  echo 'Expected service failure' >&2; exit 1
fi
cmp -s "$TMP/known-root" "$TMP/root/RustDesk2.toml"
cmp -s "$TMP/known-user" "$TMP/user/RustDesk2.toml"
hdm_confirm() { return 1; }
rc=0
hdm_rustdesk_permissions_apply full N > "$TMP/declined.log" 2>&1 || rc=$?
[[ $rc == 2 ]]
cmp -s "$TMP/known-root" "$TMP/root/RustDesk2.toml"
cmp -s "$TMP/known-user" "$TMP/user/RustDesk2.toml"
echo 'PASS RustDesk granular permissions, consent gate, dual profile, rollback on failed restart'
