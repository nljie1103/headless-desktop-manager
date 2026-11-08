#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
export HDM_PROBE_DRM_ROOT="$TMP/drm"
mkdir -p "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1" "$HDM_PROBE_DRM_ROOT/card0-Virtual-1"
source "$ROOT/core/common.sh"
source "$ROOT/core/environment.sh"
source "$ROOT/modules/quick-install/quick-install.sh"
# Real status results are read from fake sysfs, no OS changes made.
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status"
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == not-connected ]]
printf 'connected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == connected ]]
rm "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status" "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
[[ $(hdm_env_drm_state) == unknown ]]
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-HDMI-A-1/status"
# Mock desktop packages: model the four presence combinations.
DESKTOP=none
hdm_env_desktop_kind() { printf '%s\n' "$DESKTOP"; }
hdm_gnome_wayland_only() { return 1; }
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg gnome-pkg rustdesk-pkg dummy-config gdm-x11' ]]
printf 'connected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'gnome-pkg rustdesk-pkg' ]]
DESKTOP=GNOME
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
printf 'disconnected\n' > "$HDM_PROBE_DRM_ROOT/card0-Virtual-1/status"
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg rustdesk-pkg dummy-config gdm-x11' ]]
DESKTOP=XFCE
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'rustdesk-pkg' ]]
# Modern GNOME has no GDM/X11 forcing; packages alone do not claim a display.
hdm_gnome_wayland_only() { return 0; }
DESKTOP=none
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
DESKTOP=XFCE
hdm_quick_init_steps
[[ "${HDM_QUICK_STEPS[*]}" == 'dummy-pkg xfce-pkg rustdesk-pkg dummy-config' ]]
# No side-effects from read-only preflight and permission diagnostics.
output=$(bash "$ROOT/hdm.sh" --preflight)
[[ $output == *'只读安装前检测'* && $output == *'推荐操作'* ]]
output=$(bash "$ROOT/hdm.sh" --rustdesk-permissions)
[[ $output == *'只读权限诊断'* && $output == *'Polkit'* ]]
for name in etc state cache log; do [[ ! -e $TMP/$name ]]; done
# Main menu displays detection summary immediately, without modifying system.
output=$(printf '0\n' | bash "$ROOT/hdm.sh")
[[ $output == *'显示'* && $output == *'桌面'* && $output != *'快速入口'* && $output != *'建议：'* ]]
# A graphical session is not automatically a GNOME session. Regression for
# containers that run an active XFCE/X11 desktop while GDM3 is absent or active.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/loginctl" <<'MOCK_LOGINCTL'
#!/usr/bin/env bash
case "$1" in
  list-sessions) echo "c2 1000 user - - active no -" ;;
  show-session)
    case "$4" in
      Type) echo "$MOCK_SESSION_TYPE" ;;
      Class) echo "$MOCK_SESSION_CLASS" ;;
      State) echo "$MOCK_SESSION_STATE" ;;
      Desktop) echo "$MOCK_SESSION_DESKTOP" ;;
      *) exit 1 ;;
    esac ;;
  *) exit 1 ;;
esac
MOCK_LOGINCTL
chmod +x "$TMP/bin/loginctl"
mock_gnome_session() {
  PATH="$TMP/bin:$PATH" MOCK_SESSION_DESKTOP="$1" MOCK_SESSION_TYPE="$2" \
    MOCK_SESSION_CLASS="$3" MOCK_SESSION_STATE="$4" hdm_env_gnome_session
}
[[ $(mock_gnome_session xfce x11 user active) == none ]]
[[ $(mock_gnome_session ubuntu x11 user active) == x11 ]]
[[ $(mock_gnome_session gnome wayland user active) == wayland ]]
[[ $(mock_gnome_session gnome x11 greeter active) == none ]]
[[ $(mock_gnome_session '' x11 user active) == unknown ]]
mock_active_desktop() {
  PATH="$TMP/bin:$PATH" MOCK_SESSION_DESKTOP="$1" MOCK_SESSION_TYPE="$2" \
    MOCK_SESSION_CLASS=user MOCK_SESSION_STATE=active hdm_env_active_desktop_kind
}
[[ $(mock_active_desktop xfce x11) == XFCE ]]
[[ $(mock_active_desktop gnome wayland) == GNOME ]]
[[ $(mock_active_desktop mate x11) == MATE ]]
[[ $(mock_active_desktop '' x11) == none ]]
echo 'PASS environmental preflight, actual desktop/GNOME session detection and RustDesk permissions'
