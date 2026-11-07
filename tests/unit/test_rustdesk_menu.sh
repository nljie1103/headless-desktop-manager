#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log" HDM_RUSTDESK_CONFIG_ROOT="$TMP/RustDesk2.toml"
mkdir -p "$HDM_STATE" "$HDM_ETC" "$HDM_LOG_DIR" "$HDM_CACHE/downloads"
source "$ROOT/core/common.sh"
source "$ROOT/core/operation.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
source "$ROOT/ui/actions.sh"
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_snapshot_create() {
  HDM_LAST_SNAPSHOT=fixture
  : > "$TMP/snapshot.manifest"
  local path idx=0
  for path in "$@"; do
    idx=$((idx+1))
    printf '%s\t%s\n' "$path" "$idx" >> "$TMP/snapshot.manifest"
    if [[ -f $path ]]; then cp -p -- "$path" "$TMP/snapshot-$idx"; else rm -f -- "$TMP/snapshot-$idx"; fi
  done
}
hdm_snapshot_restore() {
  local path idx
  while IFS=$'\t' read -r path idx; do
    if [[ -f "$TMP/snapshot-$idx" ]]; then
      cp -p -- "$TMP/snapshot-$idx" "$path"
    else
      rm -f -- "$path"
    fi
  done < "$TMP/snapshot.manifest"
}
hdm_danger() { :; }
hdm_service_state() { printf 'inactive\n'; }
hdm_has() { [[ $1 == rustdesk ]] || command -v "$1" >/dev/null 2>&1; }
# No real RustDesk used or touched: stub executable for timeout(1) compatibility.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/rustdesk" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
 --get-id) echo '123456789';;
 --import-config) cp "$2" "$HDM_RUSTDESK_CONFIG_ROOT";;
 *) exit 1;;
esac
MOCK
chmod +x "$TMP/bin/rustdesk"
export PATH="$TMP/bin:$PATH"
hdm_rustdesk_draft_set id 'rd.example.com:10010'
hdm_rustdesk_draft_set relay 'rd.example.com:10011'
hdm_rustdesk_draft_set key 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345='
preview=$(hdm_dispatch 7.1.6)
[[ $preview == *'rd.example.com:10010'* && $preview == *'草稿'* && $preview == *'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345='* ]]
result=$(hdm_dispatch 7.1.8)
[[ $result == *'123456789'* && $result != *'ID 服务器（'* ]]
# Apply checks persisted TOML. No prompts; test native atomic save without calling RustDesk CLI.
hdm_dispatch 7.1.7 > "$TMP/apply.out"
grep -q 'root 配置已保存并读回一致' "$TMP/apply.out"
status=$(hdm_dispatch 7.3.1)
[[ $status == *'rd.example.com:10011'* && $status == *'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345='* ]]
# Mismatched TOML reports unverifiable rather than success.
sed -i 's/rd.example.com:10010/rd.example.com:21116/g' "$HDM_RUSTDESK_CONFIG_ROOT"
if python3 "$ROOT/scripts/rustdesk_config.py" verify "$HDM_RUSTDESK_CONFIG_ROOT" --draft "$(hdm_rustdesk_draft_file)" >/dev/null 2>&1; then
  echo 'verify should reject wrong persisted file'; exit 1
fi
[[ $(stat -c %a "$(hdm_rustdesk_draft_file)") == 600 ]]
echo 'PASS RustDesk menu actions, profile-aware save, ID lookup, readback verification'
