#!/usr/bin/env bash
# Reproduce v4.5.6: selecting XFCE when HDM's LightDM session file exists
# used to abort with "禁止备份未授权路径" before any settings were written.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d /tmp/hdm-lightdm-session-backup.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_STATE="$TMP/state"
source "$ROOT/core/common.sh"
source "$ROOT/core/backup.sh"
hdm_root() { return 0; }
hdm_info() { :; }
hdm_error() { printf 'ERROR: %s\n' "$*" >&2; return 1; }
# This test deliberately redefines hdm_backup_allow near the end to test an
# isolated existing-file restore. Earlier calls must exercise the real
# production allowlist; ShellCheck's SC2218 sees the later test-only stub.
target=/etc/lightdm/lightdm.conf.d/99-zz-hdm-session.conf
[[ $(grep -F 'target=/etc/lightdm/lightdm.conf.d/99-zz-hdm-session.conf' "$ROOT/modules/desktop/session.sh") ]]
# shellcheck disable=SC2218
hdm_backup_allow "$target"
# shellcheck disable=SC2218
hdm_backup_allow /etc/lightdm/lightdm.conf.d/90-hdm.conf
# Only the precise HDM-managed file is allowed; no whole directory, other
# LightDM config, path traversal, or lookalike filename is trusted.
for path in \
  /etc/lightdm/lightdm.conf \
  /etc/lightdm/lightdm.conf.d/99-zz-hdm-session.conf.bak \
  /etc/lightdm/lightdm.conf.d/../lightdm.conf \
  /etc/lightdm/lightdm.conf.d/99-zz-hdm-session.conf/other \
  /etc/lightdm/lightdm.conf.d; do
  if hdm_backup_allow "$path"; then
    echo "Unexpectedly allowed $path" >&2
    exit 1
  fi
done
# Snapshot is read-only as regards /etc/lightdm. This exercises the actual
# authorization + manifest path used when the target exists or is absent.
hdm_snapshot_create "$target"
manifest="$HDM_STATE/backups/$HDM_LAST_SNAPSHOT/manifest.tsv"
[[ -r $manifest ]]
if [[ -e $target ]]; then
  grep -Fxq "$(printf '%s\tpresent' "$target")" "$manifest"
  cmp -s -- "$target" "$HDM_STATE/backups/$HDM_LAST_SNAPSHOT/files$target"
else
  grep -Fxq "$(printf '%s\tmissing' "$target")" "$manifest"
fi
[[ $(stat -c %a "$manifest") == 600 ]]
# Any other LightDM configuration still fails closed.
if hdm_snapshot_create /etc/lightdm/lightdm.conf.d/unrelated.conf >/dev/null 2>&1; then
  echo 'Unauthorized backup unexpectedly succeeded' >&2
  exit 1
fi
# Also exercise a truly existing configuration file and its restoration in
# a private test directory. The production whitelist is tested above; this
# isolated override avoids ever modifying the host's /etc/lightdm.
present_file="$TMP/test-lightdm/99-zz-hdm-session.conf"
mkdir -p "$(dirname -- "$present_file")"
printf '[Seat:*]\nuser-session=xfce\n' > "$present_file"
hdm_backup_allow() { [[ $1 == "$present_file" ]]; }
hdm_snapshot_create "$present_file"
present_snapshot=$HDM_LAST_SNAPSHOT
grep -Fxq "$(printf '%s\tpresent' "$present_file")" "$HDM_STATE/backups/$present_snapshot/manifest.tsv"
printf '[Seat:*]\nuser-session=mate\n' > "$present_file"
hdm_snapshot_restore "$present_snapshot"
grep -Fxq 'user-session=xfce' "$present_file"
! grep -Fq 'user-session=mate' "$present_file"
echo 'PASS LightDM exact whitelist, existing/missing snapshot and safe isolated restore'
