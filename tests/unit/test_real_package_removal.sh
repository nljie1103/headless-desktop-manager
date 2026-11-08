#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-uninstall-first.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin"
export MOCK_CALLS="$TMP/apt.log" MOCK_DM_CALLS="$TMP/dm.log" PATH="$TMP/bin:$PATH"
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
source "$ROOT/core/common.sh"
source "$ROOT/ui/remove_packages.sh"
export HDM_TEST_MODE=1
hdm_root() { :; }
hdm_guard_platform() { :; }
hdm_type() { printf 'apt\n'; }
hdm_warn() { printf '%s\n' "$*"; }
hdm_info() { printf '%s\n' "$*"; }
# No LightDM, XFCE, MATE or Xorg: uninstall old GDM/GNOME first.
hdm_installed() {
  case "$1" in
    gdm3|gnome-shell|gnome-session|ubuntu-desktop|ubuntu-desktop-minimal|rustdesk) return 0;;
  esac
  return 1
}
hdm_env_active_desktop_kind() { printf 'GNOME\n'; }
hdm_service_state() { [[ $1 == gdm3 ]] && echo active || echo inactive; }
hdm_v2_default_dm() { echo gdm3; }
hdm_apt_call() { printf '%s\n' "$*" >> "$MOCK_CALLS"; }
hdm_confirm() { printf 'asked\n' >> "$TMP/confirm.log"; return 1; }
# Cancellation: one confirmation, zero mutating commands.
rc=0; hdm_v2_remove_real gdm3 > "$TMP/cancel.log" || rc=$?
[[ $rc == 2 && ! -s $MOCK_CALLS ]]
[[ $(wc -l < "$TMP/confirm.log") == 1 ]]
grep -q 'APT 计划删除' "$TMP/cancel.log"
grep -q '独立 SSH / 云控制台' "$TMP/cancel.log"
hdm_confirm() { printf 'asked\n' >> "$TMP/confirm.log"; return 0; }
# Proceed with GDM3 removal despite active GDM3 and no replacement installed.
hdm_v2_remove_real gdm3 > "$TMP/gdm.log"
grep -qx 'remove -y gdm3' "$MOCK_CALLS"
[[ $(wc -l < "$TMP/confirm.log") == 2 ]]
[[ $(grep -c 'APT 计划删除' "$TMP/gdm.log") == 1 ]]
hdm_v2_remove_real gnome > "$TMP/gnome.log"
grep -q '^remove -y .*gnome-shell' "$MOCK_CALLS"
[[ $(wc -l < "$TMP/confirm.log") == 3 ]]
# Unexpected dependencies block BEFORE prompting, no mutation.
for p in rustdesk openssh-server xserver-xorg-core lightdm systemd; do
  export MOCK_EXTRA=$p
  calls=$(wc -l < "$MOCK_CALLS")
  asked=$(wc -l < "$TMP/confirm.log")
  rc=0; hdm_v2_remove_real gdm3 > "$TMP/blocked.log" || rc=$?
  [[ $rc == 2 ]]
  [[ $(wc -l < "$MOCK_CALLS") == "$calls" ]]
  [[ $(wc -l < "$TMP/confirm.log") == "$asked" ]]
  grep -q '拒绝执行' "$TMP/blocked.log"
done
unset MOCK_EXTRA
# Choosing a login manager opens just the system picker, without two prompts.
hdm_installed() {
  case "$1" in lightdm|xfce4-session|gdm3) return 0;; esac
  return 1
}
hdm_v2_default_dm() { echo lightdm; }
asked=$(wc -l < "$TMP/confirm.log")
hdm_v2_choose_dm lightdm > "$TMP/switch.log"
grep -qx lightdm "$MOCK_DM_CALLS"
[[ $(wc -l < "$TMP/confirm.log") == "$asked" ]]
echo 'PASS uninstall-first with live GDM/GNOME, exactly one confirmation, protected dependencies and direct DM selection'
