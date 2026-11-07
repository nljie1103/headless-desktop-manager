#!/usr/bin/env bash
# Simulated active RustDesk service with two config scopes; never touches system files.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log" \
       HDM_RUSTDESK_CONFIG_ROOT="$TMP/root/RustDesk2.toml" SUDO_USER=ubuntu
mkdir -p "$HDM_STATE" "$HDM_ETC" "$HDM_LOG_DIR" "$HDM_CACHE/downloads" "${HDM_RUSTDESK_CONFIG_ROOT%/*}" "$TMP/user"
source "$ROOT/core/common.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_danger() { :; }
hdm_has() { [[ $1 == rustdesk ]] || command -v "$1" >/dev/null 2>&1; }
hdm_service_state() { echo active; }
hdm_rustdesk_get_id() { echo 'device-id 123'; }
hdm_rustdesk_login_profile() { printf '%s\t%s\t%s\n' "$TMP/user/RustDesk2.toml" "$(id -u)" "$(id -g)"; }
HDM_LAST_SNAPSHOT=''
hdm_snapshot_create() {
  HDM_LAST_SNAPSHOT=stub
  : > "$TMP/backup-list"
  local path count=0
  for path in "$@"; do
    count=$((count+1))
    printf '%s\t%s\n' "$path" "$count" >> "$TMP/backup-list"
    if [[ -f $path ]]; then cp -p "$path" "$TMP/bak-$count"; else rm -f "$TMP/bak-$count"; fi
  done
}
hdm_snapshot_restore() {
  local path count
  while IFS=$'\t' read -r path count; do
    if [[ -f $TMP/bak-$count ]]; then cp -p "$TMP/bak-$count" "$path"; else rm -f "$path"; fi
  done < "$TMP/backup-list"
}
FAIL_START=0
systemctl() {
  case "$1" in
    stop) return 0;;
    start) [[ $FAIL_START == 0 ]] || return 1;;
    *) return 1;;
  esac
}
cat > "$HDM_RUSTDESK_CONFIG_ROOT" <<'EOF'
[options]
key = 'oldroot'
old-option = 'unchanged'
EOF
cat > "$TMP/user/RustDesk2.toml" <<'EOF'
[options]
key = 'olduser'
old-option = 'unchanged'
EOF
hdm_rustdesk_draft_set id 'rd.example.test:10010'
hdm_rustdesk_draft_set relay 'rd.example.test:10011'
hdm_rustdesk_draft_set key 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345='
hdm_rustdesk_draft_apply > "$TMP/normal.out"
python3 "$ROOT/scripts/rustdesk_config.py" verify "$HDM_RUSTDESK_CONFIG_ROOT" --draft "$(hdm_rustdesk_draft_file)" >/dev/null
python3 "$ROOT/scripts/rustdesk_config.py" verify "$TMP/user/RustDesk2.toml" --draft "$(hdm_rustdesk_draft_file)" >/dev/null
grep -q "old-option = 'unchanged'" "$TMP/user/RustDesk2.toml"
grep -q 'root 配置已保存' "$TMP/normal.out"
cp "$HDM_RUSTDESK_CONFIG_ROOT" "$TMP/root-before"
cp "$TMP/user/RustDesk2.toml" "$TMP/user-before"
# On the second change a failed service restart must revert *both* profiles.
hdm_rustdesk_draft_set id 'different.example.test:10010'
FAIL_START=1
if hdm_rustdesk_draft_apply > "$TMP/failed.out" 2>&1; then
  echo 'Expected service restart failure' >&2; exit 1
fi
cmp -s "$TMP/root-before" "$HDM_RUSTDESK_CONFIG_ROOT"
cmp -s "$TMP/user-before" "$TMP/user/RustDesk2.toml"
echo 'PASS RustDesk dual profile save, service restart validation and transaction rollback'
