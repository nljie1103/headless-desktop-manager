#!/usr/bin/env bash
# HDM self-contained installer. Execute locally or fetch canonical GitHub HEADLESS source.
set -euo pipefail
REPO='nljie1103/headless-desktop-manager'
URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/main"
SOURCE=''
EXPECTED_SHA256=''
MODE='main'
usage() {
  cat <<'HELP'
Usage:
  sudo bash install.sh                      # from local project folder or download published main snapshot
  sudo bash install.sh --local              # require local project source (recommended for testing)
  sudo bash install.sh --sha256 HASH        # pin sha256 of remote archive (independently verified)
Note: main branch is a developer snapshot, not a signed stable release.
HELP
}
while (($#)); do
  case "$1" in
    --local) MODE=local; shift;;
    --sha256) [[ $# -ge 2 && $2 =~ ^[0-9a-fA-F]{64}$ ]] || { echo 'SHA256 格式错误' >&2; exit 2; }; EXPECTED_SHA256=$2; shift 2;;
    --help|-h) usage; exit 0;;
    *) echo "未知选项：$1" >&2; exit 2;;
  esac
done
[[ $EUID -eq 0 ]] || { echo '请用 sudo bash install.sh 运行。' >&2; exit 1; }
for tool in bash tar mktemp sha256sum python3; do command -v "$tool" >/dev/null || { echo "缺少基础工具：$tool" >&2; exit 1; }; done
if [[ $(uname -s) != Linux ]]; then
  echo 'HDM 只能安装到 Linux，当前内核不是 Linux。' >&2; exit 1
fi
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'HDM 实验安装器：检测到 %s / %s / %s\n' "${PRETTY_NAME:-${ID:-Linux}}" "${VERSION_ID:-unknown}" "$(uname -m)"
else
  printf 'HDM 实验安装器：未找到 os-release，继续部署 HDM 本体；安装组件时将检查包管理器。\n'
fi
printf '%s\n' '测试模式：不按发行版/CPU 白名单拦截；不会跳过软件包依赖、签名与下载校验。'
STAGE=$(mktemp -d /tmp/hdm-bootstrap.XXXXXXXX)
cleanup() { rm -rf -- "$STAGE"; }
trap cleanup EXIT
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -f "$HERE/hdm.sh" && -f "$HERE/VERSION" ]]; then
  SOURCE=$HERE
  echo "使用本地项目源码：$SOURCE"
else
  [[ $MODE == local ]] && { echo '--local 指定后当前目录必须包含完整源码。' >&2; exit 1; }
  command -v curl >/dev/null || { echo '缺少 curl，请安装系统 curl 或从 ZIP 本地安装。' >&2; exit 1; }
  echo "即将从 $URL 下载当前 main 分支源码。"
  echo '安全提示：main 分支内容可能改变。建议正式发布后固定 Release 版本及独立签名。'
  if [[ -z $EXPECTED_SHA256 ]]; then
    echo '提示：下载的是可变 main 分支，通过 HTTPS 传输，但未经独立 SHA256/签名固定。'
    echo '安装器仅部署 HDM 管理工具；修改桌面显示服务仍需在菜单中确认。'
  fi
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --tlsv1.2 --max-time 120 -o "$STAGE/source.tar.gz" "$URL"
  if [[ -n $EXPECTED_SHA256 ]]; then
    printf '%s  %s\n' "$EXPECTED_SHA256" "$STAGE/source.tar.gz" | sha256sum --status -c - || { echo 'SHA256 不匹配' >&2; exit 1; }
  fi
  # Reject absolute paths, traversal, symlinks, devices and extremely large snapshots.
  python3 - "$STAGE/source.tar.gz" <<'EOS_PY'
import sys,tarfile
from pathlib import PurePosixPath
with tarfile.open(sys.argv[1],'r:gz') as tar:
    items=tar.getmembers()
    if len(items)>3000: raise SystemExit('too many archive members')
    total=0
    for item in items:
        p=PurePosixPath(item.name)
        if p.is_absolute() or '..' in p.parts or not (item.isfile() or item.isdir()) or p.parts[0]!='headless-desktop-manager-main':
            raise SystemExit('unsafe archive member: '+item.name)
        total+=item.size
        if total>100*1024*1024: raise SystemExit('oversized archive')
EOS_PY
  mkdir -p "$STAGE/source"
  tar -xzf "$STAGE/source.tar.gz" --strip-components=1 --no-same-owner --no-same-permissions -C "$STAGE/source"
  SOURCE="$STAGE/source"
fi
[[ -f $SOURCE/hdm.sh && -f $SOURCE/VERSION && -f $SOURCE/ui/menus.tsv && -f $SOURCE/core/common.sh ]] || { echo '源码不完整，拒绝安装' >&2; exit 1; }
VERSION=$(cat "$SOURCE/VERSION")
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo '版本文件不合法' >&2; exit 1; }
bash -n "$SOURCE/hdm.sh"
python3 "$SOURCE/scripts/verify-menus.py"
TARGET="/opt/hdm/releases/v$VERSION"
mkdir -p /opt/hdm/releases /etc/hdm /var/lib/hdm /var/cache/hdm /var/log/hdm
chmod 700 /etc/hdm /var/lib/hdm /var/cache/hdm /var/log/hdm
if [[ -e $TARGET ]]; then
  echo "已存在同版本 $TARGET。不会覆盖，建议通过 HDM 更新菜单管理。"
  exit 0
fi
mkdir -p "$STAGE/release"
cp -a "$SOURCE/." "$STAGE/release/"
find "$STAGE/release" -name '__pycache__' -type d -prune -exec rm -rf {} +
mkdir -p "$TARGET"
cp -a "$STAGE/release/." "$TARGET/"
chmod +x "$TARGET/hdm.sh" "$TARGET/install.sh"
ln -s "$TARGET" "/opt/hdm/.current.$$"
mv -Tf "/opt/hdm/.current.$$" /opt/hdm/current
ln -sfn /opt/hdm/current/hdm.sh /usr/local/bin/hdm
printf '\nHDM v%s 已安装到 %s\n后续输入：sudo hdm\n' "$VERSION" "$TARGET"
printf '本次安装只部署管理器自身；GNOME/RustDesk 不会在首次安装时静默改变。\n'
