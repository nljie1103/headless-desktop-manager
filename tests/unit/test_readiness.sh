#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
source "$ROOT/core/common.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
source "$ROOT/modules/diagnostics/readiness.sh"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_RUSTDESK_CONFIG_ROOT="$TMP/RustDesk2.toml"
hdm_os() { printf 'ubuntu 26.04'; }
hdm_arch() { printf 'aarch64'; }
hdm_env_desktop_kind() { printf 'GNOME'; }
hdm_env_drm_state() { printf 'unknown'; }
hdm_env_active_session() { printf 'none'; }
hdm_env_gnome_session() { printf 'none'; }
hdm_gnome_wayland_only() { return 0; }
hdm_installed() { [[ $1 == gnome-shell || $1 == gnome-session-bin || $1 == gdm3 || $1 == rustdesk ]]; }
hdm_pkg_version() { printf 'mock-installed'; }
hdm_service_state() { [[ $1 == rustdesk ]] && printf 'active' || printf 'inactive'; }
hdm_rustdesk_login_profile() { return 1; }
result=$(hdm_readiness_report)
grep -q '\[已安装\].*GNOME Shell' <<< "$result"
grep -q '\[待安装\].*PipeWire' <<< "$result"
grep -q '\[待启动\].*gdm3' <<< "$result"
grep -q '\[未建立\].*图形用户会话' <<< "$result"
grep -q '\[未建立\].*GNOME 用户会话' <<< "$result"
if [[ $(id -u) == 0 ]]; then
  grep -q '\[待配置\].*root 服务器配置' <<< "$result"
else
  grep -q '\[待检查\].*RustDesk 服务器配置' <<< "$result"
fi
grep -q '\[待实测\].*远程画面' <<< "$result"
[[ ! -e $HDM_RUSTDESK_CONFIG_ROOT ]]
cat > "$HDM_RUSTDESK_CONFIG_ROOT" <<'TOML'
rendezvous_server = "rd.example.test:10010"
[options]
custom-rendezvous-server = "rd.example.test:10010"
relay-server = "rd.example.test:10011"
key = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234="
TOML
if [[ $(id -u) == 0 ]]; then
  result=$(hdm_readiness_report)
  grep -q '\[已配置\].*root 服务器配置' <<< "$result"
fi
# A generic active XFCE X11 session does not mean GNOME readiness.
hdm_env_active_session() { printf 'x11'; }
hdm_env_gnome_session() { printf 'none'; }
result=$(hdm_readiness_report)
grep -q '\[会话运行\].*图形用户会话' <<< "$result"
grep -q '\[未建立\].*GNOME 用户会话' <<< "$result"
grep -q 'GNOME 会话尚未确认' <<< "$result"
hdm_env_gnome_session() { printf 'wayland'; }
result=$(hdm_readiness_report)
grep -q '\[GNOME 会话\].*wayland' <<< "$result"
echo 'PASS readiness package states, GNOME-only session state, RustDesk config and read-only behavior'
