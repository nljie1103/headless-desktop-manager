#!/usr/bin/env bash
# Regression: official Release update must preserve the executable HDM command
# even with sudo's restrictive umask. Everything is under a temp test directory.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-official-permissions.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ROOT=$ROOT HDM_UPDATE_BASE="$TMP/install"
export HDM_ETC="$TMP/etc" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
export HDM_VERSION=4.4.1
mkdir -p "$TMP/headless-desktop-manager" "$TMP/install/releases" "$TMP/cache/downloads" "$TMP/log"
printf '4.4.2\n' > "$TMP/headless-desktop-manager/VERSION"
printf '#!/usr/bin/env bash\nprintf "HDM 4.4.2\\n"\n' > "$TMP/headless-desktop-manager/hdm.sh"
printf '#!/usr/bin/env bash\n' > "$TMP/headless-desktop-manager/install.sh"
chmod 600 "$TMP/headless-desktop-manager/hdm.sh" "$TMP/headless-desktop-manager/install.sh"
tar -czf "$TMP/fixture.tar.gz" -C "$TMP" headless-desktop-manager
DIGEST=$(sha256sum "$TMP/fixture.tar.gz"); DIGEST=${DIGEST%% *}
mkdir -p "$TMP/old"
printf '#!/usr/bin/env bash\n' > "$TMP/old/hdm.sh"
ln -s "$TMP/old" "$TMP/install/current"
source "$ROOT/core/common.sh"
source "$ROOT/modules/updater/updater.sh"
hdm_root() { return 0; }
hdm_danger() { return 0; }
hdm_release_query() {
  printf 'v4.4.2\thdm-v4.4.2.tar.gz\t%s\thttps://github.com/nljie1103/headless-desktop-manager/releases/download/v4.4.2/hdm-v4.4.2.tar.gz\t723430674\n' "$DIGEST"
}
hdm_download_verified() {
  [[ $3 == "$DIGEST" ]] || return 1
  cp -- "$TMP/fixture.tar.gz" "$2"
}
umask 077
hdm_update_install latest > "$TMP/result.log"
[[ $(readlink "$TMP/install/current") == "$TMP/install/releases/v4.4.2" ]]
target="$TMP/install/releases/v4.4.2"
[[ -x $target/hdm.sh && -x $target/install.sh ]]
[[ $(stat -c %a "$target/hdm.sh") == 755 ]]
[[ $(stat -c %a "$target") == 755 ]]
[[ $(stat -c %a "$target/VERSION") == 644 ]]
[[ $(bash "$target/hdm.sh") == 'HDM 4.4.2' ]]
[[ -e $TMP/old/hdm.sh ]]
# A second invocation should not replace the release directory.
if hdm_update_install latest > "$TMP/second.log"; then
  echo 'official update allowed an unsafe same-version reinstall' >&2; exit 1
fi
echo 'PASS official release update under umask 077: executable HDM command, readable code, atomic version pointer'
