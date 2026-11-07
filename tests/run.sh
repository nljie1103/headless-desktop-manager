#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
find "$ROOT" -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 "$ROOT/scripts/verify-menus.py"
bash "$ROOT/hdm.sh" --self-test
bash "$ROOT/hdm.sh" --version | grep -Fq "$(cat "$ROOT/VERSION")"
[[ $(bash "$ROOT/hdm.sh" --menu-tree | wc -l) -ge 470 ]]
printf '0\n' | bash "$ROOT/hdm.sh" > "$TMP/menu.out"
grep -q '一键安装推荐组合' "$TMP/menu.out"
python3 "$ROOT/tests/unit/test_release.py"
python3 "$ROOT/tests/unit/test_archive.py"
python3 "$ROOT/tests/unit/test_spec.py"
python3 "$ROOT/tests/unit/test_commit_policy.py"
bash "$ROOT/tests/unit/test_runtime.sh"
python3 "$ROOT/tests/unit/test_publisher.py"
python3 "$ROOT/tests/unit/test_status.py"
echo 'PASS: syntax, menus, runtime settings/cache index, publisher checks, release parser, archive verifier, spec and commit policy'
