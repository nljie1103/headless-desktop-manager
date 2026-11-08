#!/usr/bin/env bash
# Exact menu-ID comparison: numeric-looking IDs such as 8.1 and 8.10 must
# NOT compare equal inside awk. Simulate navigation without running actions.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-menu-exact.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ROOT=$ROOT HDM_VERSION=4.5.0
export HDM_UPDATE_BASE="$TMP/not-installed"
export HDM_LOG_DIR="$TMP/no-log-dir"
source "$ROOT/ui/menu.sh"
hdm_menu_header() { printf 'MENU %s\n' "$1"; }
hdm_menu_rule() { :; }
hdm_prompt() {
  local answer
  printf '%s' "$1"
  IFS= read -r answer || return 1
  printf -v "$2" '%s' "$answer"
}
hdm_pause() { :; }
hdm_warn() { printf 'WARN %s\n' "$*"; }
hdm_show() { printf 'ACTION %s\n' "$*"; }
hdm_menu_execute() { printf '%s\n' "$1" >> "$TMP/calls"; }
[[ $(hdm_menu_label 8.1) == '更新 HDM（最新正式版）' ]]
[[ $(hdm_menu_label 8.7) == '高级维护' ]]
[[ $(hdm_menu_action_target 8.1) == 'new:script-update' ]]
# Exhaustively check every entry, not only a single known collision.
declare -A has_children=()
while IFS='|' read -r parent _ _ ident; do
  [[ $parent == root || $parent == \#* ]] || has_children["$parent"]=1
done < "$ROOT/ui/menus.tsv"
while IFS='|' read -r parent code label ident; do
  [[ $parent == \#* || -z $ident ]] && continue
  [[ $(hdm_menu_label "$ident") == "$label" ]] || {
    echo "Wrong label for ID $ident" >&2; exit 1;
  }
  if [[ -n ${has_children[$ident]:-} ]]; then
    hdm_menu_has_children "$ident" || { echo "Missing children for $ident" >&2; exit 1; }
  else
    ! hdm_menu_has_children "$ident" || { echo "False child for leaf $ident" >&2; exit 1; }
  fi
done < "$ROOT/ui/menus.tsv"
! hdm_menu_has_children 8.1
hdm_menu_has_children 8.7
! hdm_menu_has_children 8.7.1
hdm_menu_has_children 8.7.17
! hdm_menu_has_children 2.3
: > "$TMP/calls"
printf '8\n1\n0\n0\n' | hdm_menu root > "$TMP/menu-update.out"
grep -qx 8.1 "$TMP/calls"
! grep -q 'MENU 8.1$' "$TMP/menu-update.out"
: > "$TMP/calls"
printf '2\n3\n0\n0\n' | hdm_menu root > "$TMP/menu-remove.out"
grep -qx 2.3 "$TMP/calls"
: > "$TMP/calls"
printf '4\n1\n0\n0\n' | hdm_menu root > "$TMP/menu-install.out"
grep -qx 4.1 "$TMP/calls"
echo 'PASS exact numeric-like menu IDs, direct update/removal/install and audited menu navigation'
