#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_TEST_MODE=1 HDM_LOG_DIR="$TMP/log" HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache"
mkdir -p "$HDM_LOG_DIR" "$TMP/bin"
source "$ROOT/core/common.sh"
source "$ROOT/modules/diagnostics/diagnostics.sh"
source "$ROOT/modules/display/display.sh"
source "$ROOT/ui/actions.sh"
hdm_root() { return 0; }
hdm_type() { printf 'apt\n'; }
hdm_installed() { [[ $1 == xfce4 || $1 == rustdesk ]]; }
hdm_has() { [[ $1 == apt-get ]] || command -v "$1" >/dev/null; }
cat > "$TMP/bin/apt-get" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$AUDIT_APT_CALLS"
if [[ $1 == -s && $2 == remove ]]; then
  printf 'Reading package lists...\nRemv %s [1.0]\n' "$3"
else
  printf 'WRONG MUTATING COMMAND' >&2
  exit 91
fi
MOCK
chmod +x "$TMP/bin/apt-get"
export PATH="$TMP/bin:$PATH" AUDIT_APT_CALLS="$TMP/apt.calls"
out=$(hdm_action_remove_preview rustdesk)
[[ $out == *'只读'* && $out == *'删除 1 个软件包'* ]]
out=$(hdm_action_desktop_remove_preview)
[[ $out == *'xfce4'* && $out == *'删除 1 个软件包'* ]]
[[ $(wc -l < "$AUDIT_APT_CALLS") == 2 ]]
! grep -vE '^-s remove (rustdesk|xfce4)$' "$AUDIT_APT_CALLS"
if hdm_action_remove_preview /bin/bash >/dev/null; then
  echo 'Unexpected package accepted' >&2
  exit 1
fi
touch "$HDM_LOG_DIR/operation-old.log" "$HDM_LOG_DIR/operation-recent.log"
touch "$HDM_LOG_DIR/hdm.log" "$HDM_LOG_DIR/steps.log" "$TMP/external"
touch -d '50 days ago' "$HDM_LOG_DIR/operation-old.log" "$HDM_LOG_DIR/hdm.log" "$HDM_LOG_DIR/steps.log"
ln -s "$TMP/external" "$HDM_LOG_DIR/operation-symlink.log"
hdm_danger() { return 1; }
rc=0; hdm_diag_prune_logs >/dev/null || rc=$?
[[ $rc == 2 && -f $HDM_LOG_DIR/operation-old.log ]]
hdm_danger() { return 0; }
hdm_diag_prune_logs >/dev/null
[[ ! -e $HDM_LOG_DIR/operation-old.log ]]
[[ -f $HDM_LOG_DIR/operation-recent.log && -f $HDM_LOG_DIR/hdm.log ]]
[[ -f $HDM_LOG_DIR/steps.log && -e $TMP/external && -L $HDM_LOG_DIR/operation-symlink.log ]]
# Only HDM-owned regular files are eligible for Dummy configuration deletion.
printf '# User-managed Xorg config\n' > "$TMP/custom.conf"
printf '# Managed by HDM\n' > "$TMP/managed.conf"
ln -s "$TMP/managed.conf" "$TMP/managed-link.conf"
! hdm_display_owned_dummy_config "$TMP/custom.conf"
hdm_display_owned_dummy_config "$TMP/managed.conf"
! hdm_display_owned_dummy_config "$TMP/managed-link.conf"
echo 'PASS APT removal preview, safe log retention and HDM-owned display file verification'
