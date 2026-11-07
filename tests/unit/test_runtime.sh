#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
mkdir -p "$HDM_ETC" "$HDM_STATE" "$HDM_CACHE/downloads" "$HDM_LOG_DIR"
# Safe unit tests: source only, no systemctl or APT calls.
source "$ROOT/core/common.sh"
source "$ROOT/modules/display/display.sh"
source "$ROOT/modules/rustdesk/rustdesk.sh"
hdm_root() { :; }
hdm_init
hdm_setting HDM_XVFB_DISPLAY 101
hdm_setting HDM_XVFB_RESOLUTION 1280x720
hdm_setting HDM_XVFB_DEPTH 16
hdm_xvfb_render > "$TMP/xvfb.service"
grep -q 'ExecStart=/usr/bin/Xvfb :101 -screen 0 1280x720x16 -nolisten tcp' "$TMP/xvfb.service"
if hdm_setting HDM_XVFB_DISPLAY '1; touch /tmp/pwned'; then exit 1; fi
if hdm_setting HDM_XVFB_DEPTH 500; then exit 1; fi
if hdm_setting HDM_XVFB_RESOLUTION '1000x999'; then exit 1; fi
# Simulate official-cache bytes (not a real .deb; only hash index parsing is tested).
asset=rustdesk-1.5.1-x86_64.deb
printf 'cache-fixture' > "$HDM_CACHE/downloads/$asset"
digest=$(sha256sum "$HDM_CACHE/downloads/$asset" | awk '{print $1}')
hdm_rustdesk_cache_record 1.5.1 "$asset" "$digest" "https://github.com/rustdesk/rustdesk/releases/download/1.5.1/$asset"
[[ $(hdm_rustdesk_cache_list | wc -l) -eq 1 ]]
printf 'modified' >> "$HDM_CACHE/downloads/$asset"
[[ -z $(hdm_rustdesk_cache_list) ]]
[[ $(grep -c '^HDM_XVFB_DISPLAY=' "$HDM_ETC/config.conf") -eq 1 ]]
printf 'PASS Xvfb configuration and RustDesk verified cache index\n'
