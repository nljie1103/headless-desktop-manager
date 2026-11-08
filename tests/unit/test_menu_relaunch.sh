#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/new" "$TMP/install"
printf '55.0.0\n' > "$TMP/new/VERSION"
cat > "$TMP/new/hdm.sh" <<'EOF'
#!/usr/bin/env bash
printf 'NEW_MENU_STARTED\n'
EOF
ln -s "$ROOT" "$TMP/install/current"
# Source menu without loading platform code; monkeypatch only required functions.
source "$ROOT/ui/menu.sh"
HDM_ROOT="$ROOT"
HDM_VERSION=0.3.8
HDM_UPDATE_BASE="$TMP/install"
hdm_menu_header() { :; }
hdm_menu_children() { printf '  1 更新\n'; }
hdm_menu_has_children() { [[ $1 == 8 ]]; }
hdm_menu_label() { printf '更新\n'; }
hdm_menu_main() { printf '1 更新\n'; }
hdm_prompt() { local name=$2; printf -v "$name" '%s' 1; }
hdm_show() { :; }
hdm_warn() { :; }
hdm_pause() { printf 'WRONG_PAUSE_OLD_MENU\n'; }
hdm_dispatch() {
  ln -sfn "$TMP/new" "$TMP/install/current"
}
# Use a leaf entry exactly as the real menu does; nested menu switch detected.
# Temporarily replace the menu root lookup source with a readonly fake copy.
mkdir -p "$TMP/copy/ui"
printf 'root|1|更新|8.2.5\n' > "$TMP/copy/ui/menus.tsv"
printf '8.2.5|8.2.5\n' > "$TMP/copy/ui/menu-targets.tsv"
HDM_ROOT="$TMP/copy"
output=$(hdm_menu root)
[[ $output == *'NEW_MENU_STARTED'* ]]
[[ $output != *'WRONG_PAUSE_OLD_MENU'* ]]
echo 'PASS new version relaunch replaces old menu process without returning'
