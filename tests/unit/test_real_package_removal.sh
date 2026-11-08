#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-uninstall-test.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin"
export MOCK_CALLS="$TMP/apt.log" PATH="$TMP/bin:$PATH"
cat > "$TMP/bin/apt-get" <<'SH'
#!/usr/bin/env bash
[[ $1 == -s && $2 == remove ]] || exit 99
shift 2
for p in "$@"; do printf 'Remv %s [1.0]\n' "$p"; done
if [[ -n ${MOCK_EXTRA:-} ]]; then printf 'Remv %s [1.0]\n' "$MOCK_EXTRA"; fi
SH
cat > "$TMP/bin/dpkg-reconfigure" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_DM_CALLS"
SH
chmod +x "$TMP/bin/"*
export MOCK_DM_CALLS="$TMP/dm.log"
source "$ROOT/core/common.sh"
source "$ROOT/ui/remove_packages.sh"
export HDM_TEST_MODE=1
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_type() { printf 'apt\n'; }
hdm_installed() {
  case "$1" in
    lightdm|xfce4|xfce4-session|xserver-xorg-core|gdm3|gnome-shell|gnome-session|ubuntu-desktop|ubuntu-desktop-minimal|rustdesk) return 0;;
  esac
  return 1
}
DM_DEFAULT=gdm3
LIGHTDM_RUNNING=inactive
GDM_RUNNING=active
ACTIVE_DESKTOP=none
hdm_v2_default_dm() { printf '%s\n' "$DM_DEFAULT"; }
hdm_env_active_desktop_kind() { printf '%s\n' "$ACTIVE_DESKTOP"; }
hdm_service_state() {
  case "$1" in
    lightdm) echo "$LIGHTDM_RUNNING";;
    gdm3) echo "$GDM_RUNNING";;
    *) echo unknown;;
  esac
}
hdm_apt_call() { printf '%s\n' "$*" >> "$MOCK_CALLS"; }
hdm_confirm() { return 1; }
# The user's situation: GDM active and LightDM not started -- no real remove.
if hdm_v2_remove_real gdm3 > "$TMP/blocked.txt"; then
  echo 'ERROR: removed active GDM3 without LightDM takeover' >&2; exit 1
fi
[[ ! -s $MOCK_CALLS && $(cat "$TMP/blocked.txt") == *'LightDM'* ]]
# After LightDM takes over, show a real planned deletion.
DM_DEFAULT=lightdm; LIGHTDM_RUNNING=active; GDM_RUNNING=inactive
hdm_v2_remove_plan gdm3 > "$TMP/gdm-preview.txt"
grep -q 'APT 计划删除' "$TMP/gdm-preview.txt"
# Still not removed if confirmation is denied.
if hdm_v2_remove_real gdm3 >/dev/null; then
  echo 'ERROR: cancellation ignored' >&2; exit 1
fi
[[ ! -s $MOCK_CALLS ]]
hdm_confirm() { return 0; }
hdm_v2_remove_real gdm3 > "$TMP/executed.txt"
grep -qx 'remove -y gdm3' "$MOCK_CALLS"
# A malicious/unexpected apt dependency that uninstalls RustDesk must block.
export MOCK_EXTRA=rustdesk
if hdm_v2_remove_real gdm3 > "$TMP/danger.txt"; then
  echo 'ERROR: protected dependency removed' >&2; exit 1
fi
[[ $(wc -l < "$MOCK_CALLS") == 1 ]]
unset MOCK_EXTRA
# GNOME is a distinct real uninstall path, after LightDM takeover.
hdm_v2_remove_real gnome >/dev/null
grep -q '^remove -y .*gnome-shell' "$MOCK_CALLS"
ACTIVE_DESKTOP=GNOME
if hdm_v2_remove_real gnome >/dev/null; then
  echo 'ERROR: live GNOME session deletion accepted' >&2; exit 1
fi
ACTIVE_DESKTOP=none
# Reversing direction also requires GDM3 to have taken over.
if hdm_v2_remove_real lightdm >/dev/null; then
  echo 'ERROR: live LightDM accepted for removal' >&2; exit 1
fi
# The selection action is real: invokes dpkg-reconfigure, not a message stub.
hdm_v2_choose_dm lightdm >/dev/null
grep -qx lightdm "$MOCK_DM_CALLS"
echo 'PASS real APT remove call, deny/cancel, protected packages, GNOME session guards and interactive DM reconfigure'
