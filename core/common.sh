#!/usr/bin/env bash
# Shared functions. All paths are fixed, no downloading of executable source in core.
HDM_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HDM_VERSION="$(cat "$HDM_ROOT/VERSION")"
# The installed defaults are not writable; runtime preferences are stored separately.
# shellcheck source=../config/github-endpoints.conf
source "$HDM_ROOT/config/github-endpoints.conf"
# shellcheck source=../config/defaults.conf
source "$HDM_ROOT/config/defaults.conf"
HDM_ETC=${HDM_ETC:-/etc/hdm}
HDM_STATE=${HDM_STATE:-/var/lib/hdm}
HDM_CACHE=${HDM_CACHE:-/var/cache/hdm}
HDM_LOG_DIR=${HDM_LOG_DIR:-/var/log/hdm}
HDM_LOG_FILE="$HDM_LOG_DIR/hdm.log"
HDM_LAST_ERROR=''
hdm_init() {
  umask 077
  if [[ $EUID -eq 0 ]]; then
    mkdir -p "$HDM_ETC" "$HDM_STATE/backups" "$HDM_STATE/transactions" "$HDM_CACHE/downloads" "$HDM_LOG_DIR"
    chmod 700 "$HDM_ETC" "$HDM_STATE" "$HDM_CACHE" "$HDM_LOG_DIR" 2>/dev/null || :
  fi
  if [[ -f $HDM_ETC/config.conf ]]; then
    # Config keys must be allow-listed and parsed as plain data, never source executable user config.
    while IFS='=' read -r key value; do
      [[ $key == \#* ]] && continue
      case "$key" in
        HDM_DEFAULT_RESOLUTION) [[ $value =~ ^(1280x720|1600x900|1920x1080|2560x1440)$ ]] && HDM_DEFAULT_RESOLUTION=$value ;;
        HDM_SOURCE_POLICY) [[ $value =~ ^(system-only|official-mirror|official-mirror-github|ask)$ ]] && HDM_SOURCE_POLICY=$value ;;
        HDM_RUSTDESK_CHANNEL) [[ $value =~ ^(stable|tested)$ ]] && HDM_RUSTDESK_CHANNEL=$value ;;
        HDM_XVFB_DISPLAY) [[ $value =~ ^[0-9]{2,3}$ ]] && ((10#$value >= 90 && 10#$value <= 199)) && HDM_XVFB_DISPLAY=$value ;;
        HDM_XVFB_RESOLUTION) [[ $value =~ ^(1280x720|1600x900|1920x1080|2560x1440)$ ]] && HDM_XVFB_RESOLUTION=$value ;;
        HDM_XVFB_DEPTH) [[ $value =~ ^(16|24|32)$ ]] && HDM_XVFB_DEPTH=$value ;;
      esac
    done < "$HDM_ETC/config.conf"
  fi
}
hdm_log() { local level=$1; shift; local line; line="$(date '+%F %T') [$level] $*"; if [[ $EUID -eq 0 ]]; then printf '%s\n' "$line" >> "$HDM_LOG_FILE"; fi; if [[ $level == ERROR ]]; then printf '%s\n' "$line" >&2; else printf '%s\n' "$line"; fi; }
hdm_info() { hdm_log INFO "$@"; }
hdm_warn() { hdm_log WARN "$@"; }
hdm_error() { HDM_LAST_ERROR=$*; hdm_log ERROR "$@"; return 1; }
hdm_root() { if [[ $EUID -ne 0 ]]; then hdm_error '操作需要 root 权限。请运行 sudo hdm。'; return 1; fi; }
hdm_supported() { [[ -r /etc/os-release ]] || return 1; local ID VERSION_ID; . /etc/os-release; [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 && $(uname -m) == x86_64 ]]; }
hdm_guard_platform() { if ! hdm_supported; then hdm_error '当前发行版/CPU 未经过验证。安装操作仅支持 Ubuntu 24.04 x86_64（其他平台先开放只读诊断）。'; return 1; fi; }
hdm_confirm() { local text=$1 response; printf '\n%s [y/N]: ' "$text"; IFS= read -r response || return 1; [[ $response == y || $response == Y || $response == yes ]]; }
hdm_danger() { local text=$1 response; printf '\n风险操作：%s\n请输入 YES 继续（其他任意输入取消）：' "$text"; IFS= read -r response || return 1; [[ $response == YES ]]; }
hdm_pause() { if [[ -t 0 ]]; then printf '\n按回车返回...'; IFS= read -r _ || :; fi; }
hdm_prompt() { local prompt=$1 __var=$2 answer; printf '%s' "$prompt"; IFS= read -r answer || return 1; printf -v "$__var" '%s' "$answer"; }
hdm_has() { command -v "$1" >/dev/null 2>&1; }
hdm_show() { printf '\n---- %s ----\n' "$1"; }
hdm_safe_run() { hdm_root || return 1; hdm_guard_platform || return 1; if [[ ${HDM_DRY_RUN:-0} == 1 ]]; then printf '[DRY RUN]'; printf ' %q' "$@"; printf '\n'; return 0; fi; "$@"; }
hdm_setting() { hdm_root || return 1; local key=$1 val=$2; case "$key" in
   HDM_DEFAULT_RESOLUTION|HDM_XVFB_RESOLUTION) [[ $val =~ ^(1280x720|1600x900|1920x1080|2560x1440)$ ]] || return 1;;
   HDM_SOURCE_POLICY) [[ $val =~ ^(system-only|official-mirror|official-mirror-github|ask)$ ]] || return 1;;
   HDM_RUSTDESK_CHANNEL) [[ $val =~ ^(stable|tested)$ ]] || return 1;;
   HDM_XVFB_DISPLAY) [[ $val =~ ^(9[0-9]|1[0-9][0-9])$ ]] || return 1;;
   HDM_XVFB_DEPTH) [[ $val =~ ^(16|24|32)$ ]] || return 1;;
   *) return 1;;
  esac; [[ $val != *$'\n'* && $val != *'='* ]] || return 1; mkdir -p "$HDM_ETC"; local tmp; tmp=$(mktemp "$HDM_ETC/.settings.XXXXXX") || return 1; if [[ -f $HDM_ETC/config.conf ]]; then grep -v "^${key}=" "$HDM_ETC/config.conf" > "$tmp" || :; fi; printf '%s=%s\n' "$key" "$val" >> "$tmp"; chmod 600 "$tmp"; mv -f -- "$tmp" "$HDM_ETC/config.conf"; printf -v "$key" '%s' "$val"; }
hdm_service_state() { systemctl is-active "$1" 2>/dev/null || true; }
hdm_installed() { if hdm_has dpkg-query; then dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -qx 'install ok installed'; else return 1; fi; }
hdm_pkg_version() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || printf '未安装'; }
hdm_os() { if [[ -r /etc/os-release ]]; then ( . /etc/os-release; printf '%s %s' "$ID" "$VERSION_ID" ); else uname -s; fi; }
hdm_arch() { uname -m; }
hdm_type() { [[ -f /etc/os-release ]] && . /etc/os-release; case "${ID:-}" in ubuntu|debian) printf apt;; fedora|rhel|rocky|almalinux) if hdm_has dnf; then printf dnf; else printf yum; fi;; *) printf unsupported;; esac; }
hdm_state_set() { hdm_root || return 1; local key=$1 val=$2; [[ $key =~ ^[a-z0-9_-]+$ && $val =~ ^[A-Za-z0-9_.:-]+$ ]] || return 1; printf '%s\n' "$val" > "$HDM_STATE/$key"; }
hdm_state_get() { [[ -r $HDM_STATE/$1 ]] && head -n 1 "$HDM_STATE/$1" || printf '未知'; }
