#!/usr/bin/env bash
# Offline end-to-end test of the pinned-main install path. No GitHub/real system writes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
export HDM_UPDATE_BASE="$TMP/install"
mkdir -p "$TMP/source" "$TMP/install/releases" "$TMP/log"
cp -a "$ROOT/." "$TMP/source/"
printf '0.3.7\n' > "$TMP/source/VERSION"
SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
mv "$TMP/source" "$TMP/headless-desktop-manager-$SHA"
tar -czf "$TMP/valid.tar.gz" -C "$TMP" "headless-desktop-manager-$SHA"
ln -s "$ROOT" "$TMP/install/current"
source "$ROOT/core/common.sh"
source "$ROOT/modules/updater/updater.sh"
hdm_root() { return 0; }
hdm_danger() { return 0; }
hdm_update_preview_metadata() { printf '0.3.7\t%s\n' "$SHA"; }
curl() {
    local dest='' prev='' arg
    for arg in "$@"; do
        if [[ $prev == -o ]]; then dest=$arg; break; fi
        prev=$arg
    done
    [[ -n $dest ]] || return 1
    cp -- "$TMP/valid.tar.gz" "$dest"
}
hdm_update_preview_install > "$TMP/normal.out"
[[ $(readlink "$TMP/install/current") == "$TMP/install/releases/v0.3.7" ]]
[[ -f $TMP/install/releases/v0.3.7/VERSION ]]
[[ $(cat "$TMP/install/releases/v0.3.7/VERSION") == 0.3.7 ]]
# A same-version install should not overwrite an already installed version.
if hdm_update_preview_install > "$TMP/retry.out" 2>&1; then
    echo 'Unexpected overwrite on repeat preview install' >&2
    exit 1
fi
[[ $(readlink "$TMP/install/current") == "$TMP/install/releases/v0.3.7" ]]
# Unsafe archive must not change the current symlink.
rm -rf "$TMP/install/releases/v0.3.7"
ln -sfn "$ROOT" "$TMP/install/current"
printf 'bad archive' > "$TMP/invalid.tar.gz"
curl() {
    local dest='' prev='' arg
    for arg in "$@"; do
        if [[ $prev == -o ]]; then dest=$arg; break; fi
        prev=$arg
    done
    [[ -n $dest ]] || return 1
    cp -- "$TMP/invalid.tar.gz" "$dest"
}
if hdm_update_preview_install > "$TMP/rejected.out" 2>&1; then
    echo 'Unsafe preview archive accepted' >&2
    exit 1
fi
[[ $(readlink "$TMP/install/current") == "$ROOT" ]]
if hdm_update_newer 0.3.3 0.3.4; then exit 1; fi
hdm_update_newer 0.3.7 0.3.4
printf 'PASS offline preview update, atomic pointer, no overwrite, unsafe archive rejection\n'
