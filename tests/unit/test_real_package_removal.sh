#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-uninstall-options.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin"
export MOCK_CALLS="$TMP/apt.log" MOCK_DM_CALLS="$TMP/dm.log" PATH="$TMP/bin:$PATH"
cat > "$TMP/bin/apt-get" <<'SH'
#!/usr/bin/env bash
[[ $1 == -s && ( $2 == remove || $2 == purge ) ]] || exit 99
verb=$2; shift 2
[[ $verb == purge ]] && prefix=Purg || prefix=Remv
for p in "$@"; do printf '%s %s [1.0]\n' "$prefix" "$p"; done
[[ -z ${MOCK_EXTRA:-} ]] || printf 'Remv %s [1.0]\n' "$MOCK_EXTRA"
if [[ $verb == purge && -n ${MOCK_PURGE_EXTRA:-} ]]; then
  printf 'Purg %s [1.0]\n' "$MOCK_PURGE_EXTRA"
fi
SH
cat > "$TMP/bin/dpkg-reconfigure" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_DM_CALLS"
SH
chmod +x "$TMP/bin/"*
source "$ROOT/core/common.sh"
source "$ROOT/ui/remove_packages.sh"
export HDM_TEST_MODE=1
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_type() { printf 'apt\n'; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_info() { printf '%s\n' "$*"; }
# Simulate current GNOME/GDM3 only, no LightDM/XFCE installed.
hdm_installed() {
  case "$1" in gdm3|gnome-shell|gnome-session|ubuntu-desktop|ubuntu-desktop-minimal|rustdesk) return 0;; esac
  return 1
}
hdm_env_active_desktop_kind() { echo GNOME; }
hdm_service_state() { [[ $1 == gdm3 ]] && echo active || echo inactive; }
hdm_v2_default_dm() { echo gdm3; }
hdm_apt_call() { printf '%s\n' "$*" >> "$MOCK_CALLS"; }
hdm_confirm() { echo 'unexpected confirmation' >> "$TMP/extra-confirm"; return 1; }
# Zero and q cancel without mutation, extra warning, or a second confirmation.
printf '0\n' | hdm_v2_remove_real gdm3 > "$TMP/cancel.log"
printf 'q\n' | hdm_v2_remove_real gdm3 > "$TMP/cancel-q.log"
[[ ! -s $MOCK_CALLS && ! -e $TMP/extra-confirm ]]
grep -q '已取消' "$TMP/cancel.log"
# Choice 1 must really invoke APT remove and never purge.
printf '1\n' | hdm_v2_remove_real gdm3 > "$TMP/remove.log"
grep -qx 'remove -y gdm3' "$MOCK_CALLS"
grep -q '保留配置' "$TMP/remove.log"
# Choice 2 must really invoke APT purge; Purg records are parsed.
printf '2\n' | hdm_v2_remove_real gdm3 > "$TMP/purge.log"
grep -qx 'purge -y gdm3' "$MOCK_CALLS"
grep -q '清除' "$TMP/purge.log"
[[ $(wc -l < "$MOCK_CALLS") == 2 ]]
[[ ! -e $TMP/extra-confirm ]]
# Desktop GNOME purge works without a replacement or current-session block.
printf '2\n' | hdm_v2_remove_real gnome > "$TMP/gnome.log"
grep -q '^purge -y .*gnome-shell' "$MOCK_CALLS"
# Any protected dependency blocks before mode selection for either action.
for p in rustdesk openssh-server xserver-xorg-core lightdm systemd; do
  export MOCK_EXTRA=$p
  old=$(wc -l < "$MOCK_CALLS")
  rc=0; printf '1\n' | hdm_v2_remove_real gdm3 > "$TMP/blocked.log" || rc=$?
  [[ $rc == 2 && $(wc -l < "$MOCK_CALLS") == "$old" ]]
  grep -q '拒绝执行' "$TMP/blocked.log"
done
unset MOCK_EXTRA
# Test a dependency visible ONLY in purge, after remove simulation passed.
export MOCK_PURGE_EXTRA=rustdesk
old=$(wc -l < "$MOCK_CALLS")
rc=0; printf '2\n' | hdm_v2_remove_real gdm3 > "$TMP/purge-blocked.log" || rc=$?
[[ $rc == 2 && $(wc -l < "$MOCK_CALLS") == "$old" ]]
grep -q '拒绝执行' "$TMP/purge-blocked.log"
unset MOCK_PURGE_EXTRA
# No redundant prompt before dpkg-reconfigure.
hdm_installed() { case "$1" in lightdm|xfce4-session|gdm3) return 0;; esac; return 1; }
hdm_v2_default_dm() { echo lightdm; }
hdm_v2_choose_dm lightdm > "$TMP/switch.log"
grep -qx lightdm "$MOCK_DM_CALLS"
[[ ! -e $TMP/extra-confirm ]]
echo 'PASS direct remove/purge choices, cancellation, active GNOME removal, protected dependencies and single step'
