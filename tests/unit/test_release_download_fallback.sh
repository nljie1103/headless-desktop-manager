#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-release-fallback.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
mkdir -p "$TMP/cache/downloads"
source "$ROOT/core/common.sh"
source "$ROOT/core/downloader.sh"
URL=https://github.com/nljie1103/headless-desktop-manager/releases/download/v4.3.1/hdm-v4.3.1.tar.gz
API=https://api.github.com/repos/nljie1103/headless-desktop-manager/releases/assets/723430674
printf 'validated HDM archive bytes\n' > "$TMP/fixture"
DIGEST=$(sha256sum "$TMP/fixture")
DIGEST=${DIGEST%% *}
export API_CALLS="$TMP/calls"
curl() {
  local url='' output='' previous='' arg
  for arg in "$@"; do
    [[ $previous == -o ]] && output=$arg
    previous=$arg
    case "$arg" in https://*) url=$arg;; esac
  done
  printf '%s\n' "$url" >> "$API_CALLS"
  case "$url" in
    "$URL") printf 'curl: (22) 504\n' >&2; return 22;;
    "$API") cp -- "$TMP/fixture" "$output"; return 0;;
    *) printf 'unexpected URL: %s\n' "$url" >&2; return 92;;
  esac
}
hdm_download_verified "$URL" "$TMP/cache/downloads/hdm-v4.3.1.tar.gz" "$DIGEST" 723430674 > "$TMP/ok.out" 2>&1
cmp "$TMP/fixture" "$TMP/cache/downloads/hdm-v4.3.1.tar.gz"
[[ $(wc -l < "$API_CALLS") == 2 ]]
grep -Fqx "$API" "$API_CALLS"
grep -q 'API 下载同一资产' "$TMP/ok.out"
# A mismatched SHA256 MUST fail even if the backup source returns bytes.
: > "$API_CALLS"
if hdm_download_verified "$URL" "$TMP/invalid.tar.gz" "$(printf '0%.0s' {1..64})" 723430674 > "$TMP/rejected.out" 2>&1; then
  echo 'Accepted an invalid digest' >&2; exit 1
fi
[[ ! -e $TMP/invalid.tar.gz ]]
grep -q 'SHA256 校验失败' "$TMP/rejected.out"
# Only a valid, numeric asset ID from HDM's own release allows fallback.
: > "$API_CALLS"
if hdm_download_verified "$URL" "$TMP/noid.tar.gz" "$DIGEST" not-an-id > "$TMP/noid.out" 2>&1; then
  echo 'Accepted a forged API asset ID' >&2; exit 1
fi
[[ $(wc -l < "$API_CALLS") == 1 ]]
[[ ! -e $TMP/noid.tar.gz ]]
echo 'PASS release direct-link 504 -> same-asset API SHA256 fallback, tamper rejection, asset-ID bounds'
