#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HDM_LOG_DIR="$TMP/log" HDM_CACHE="$TMP/cache" HDM_STATE="$TMP/state" HDM_ETC="$TMP/etc"
mkdir -p "$HDM_LOG_DIR" "$HDM_CACHE/downloads" "$HDM_STATE"
source "$ROOT/core/common.sh"
source "$ROOT/core/operation.sh"
source "$ROOT/core/packages.sh"
hdm_root() { return 0; }
hdm_guard_platform() { return 0; }
# Prevent any real APT execution; mock apt-get via isolated executable in PATH.
mkdir "$TMP/bin"
cat > "$TMP/bin/apt-get" <<'MOCK'
#!/usr/bin/env bash
printf 'HUGE DETAIL LINE MUST BE HIDDEN\n'
case "${APT_TEST_RESULT:-ok}" in
  ok) exit 0;;
  disk) echo 'No space left on device' >&2; exit 100;;
  dns) echo 'Temporary failure resolving mirror.example' >&2; exit 100;;
  timeout) echo 'Connection timed out' >&2; exit 100;;
  mirror) echo 'Failed to fetch 404 Not Found' >&2; exit 100;;
  sig) echo 'NO_PUBKEY BADSIG' >&2; exit 100;;
  deps) echo 'Unable to correct problems, you have held broken packages' >&2; exit 100;;
esac
MOCK
chmod +x "$TMP/bin/apt-get"
export PATH="$TMP/bin:$PATH" HDM_SOURCE_POLICY=system-only
output=$(hdm_apt_call install -y testpkg 2>&1)
[[ $output == *'[成功]'* && $output != *'HUGE DETAIL LINE'* ]]
for item in disk dns timeout mirror sig deps; do
  export APT_TEST_RESULT=$item
  output=$(hdm_apt_call install -y testpkg 2>&1) && { echo "error: $item should fail"; exit 1; }
  [[ $output != *'HUGE DETAIL LINE'* ]]
  case $item in
    disk) [[ $output == *'磁盘空间不足'* ]];;
    dns) [[ $output == *'DNS'* ]];;
    timeout) [[ $output == *'超时'* ]];;
    mirror) [[ $output == *'镜像站'* ]];;
    sig) [[ $output == *'签名'* ]];;
    deps) [[ $output == *'依赖冲突'* ]];;
  esac || { echo "bad classification: $item : $output"; exit 1; }
done
[[ $(find "$HDM_LOG_DIR" -type f | wc -l) -ge 7 ]]
[[ $(stat -c %a "$(find "$HDM_LOG_DIR" -type f | head -1)") == 600 ]]
echo 'PASS quiet apt operations and error categories'
