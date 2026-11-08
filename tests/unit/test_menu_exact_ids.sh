#!/usr/bin/env bash
# Exhaustively verify IDs such as 3.1 and 3.10 do not match each other.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-menu-exact.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ROOT=$ROOT HDM_VERSION=4.5.9
export HDM_UPDATE_BASE="$TMP/not-installed"
export HDM_LOG_DIR="$TMP/no-log-dir"
source "$ROOT/ui/menu.sh"
hdm_menu_header() { printf 'MENU %s\n' "$1"; }
hdm_menu_rule() { :; }
hdm_prompt() { local ans; printf '%s' "$1"; IFS= read -r ans || return 1; printf -v "$2" '%s' "$ans"; }
hdm_pause() { :; }
hdm_warn() { printf 'WARN %s\n' "$*"; }
hdm_show() { printf 'ACTION %s\n' "$*"; }
hdm_menu_execute() { printf '%s\n' "$1" >> "$TMP/calls"; }

[[ $(hdm_menu_label 8.4) == '更新 HDM（最新正式版）' ]]
[[ $(hdm_menu_action_target 8.4) == 'new:script-update' ]]
[[ $(hdm_menu_action_target 2.1) == 'new:dm-install-lightdm' ]]
[[ $(hdm_menu_action_target 2.10) == 'new:dm-remove-gdm3' ]]
[[ $(hdm_menu_action_target 8.1) == 'new:quick-install' ]]
declare -A children=()
while IFS='|' read -r parent _ _ ident; do
  [[ $parent == root || $parent == \#* ]] || children["$parent"]=1
done < "$ROOT/ui/menus.tsv"
while IFS='|' read -r parent code label ident; do
  [[ $parent == \#* || -z $ident ]] && continue
  [[ $(hdm_menu_label "$ident") == "$label" ]]
  if [[ -n ${children[$ident]:-} ]]; then hdm_menu_has_children "$ident"
  else ! hdm_menu_has_children "$ident"; fi
done < "$ROOT/ui/menus.tsv"
! hdm_menu_has_children 8.4
hdm_menu_has_children 2.11
! hdm_menu_has_children 2.10
: > "$TMP/calls"
printf '8\n4\n0\n0\n' | hdm_menu root > "$TMP/menu-update.out"
grep -qx 8.4 "$TMP/calls"
: > "$TMP/calls"
printf '2\n10\n0\n0\n' | hdm_menu root > "$TMP/menu-remove.out"
grep -qx 2.10 "$TMP/calls"
! grep -qx 4.1 "$TMP/calls"
: > "$TMP/calls"
printf '4\n1\n0\n0\n' | hdm_menu root > "$TMP/menu-install.out"
grep -qx 4.1 "$TMP/calls"
echo 'PASS exact IDs and compact user actions'
