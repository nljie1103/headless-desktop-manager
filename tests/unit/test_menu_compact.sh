#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
output=$(printf '0\n' | COLUMNS=100 bash "$ROOT/hdm.sh")
[[ $output == *'1. 安装虚拟显示器'* && $output == *'6. 更新 RustDesk'* ]]
[[ $output == *'10. 系统诊断与日志'* && $output != *'快速入口'* && $output != *'实验'* ]]
[[ $output != *'建议：'* && $output == *'桌面包'* ]]
output=$(printf '0\n' | COLUMNS=54 bash "$ROOT/hdm.sh")
[[ $output == *'1.  安装虚拟显示器'* && $output == *'10. 系统诊断与日志'* ]]
python3 - "$ROOT" <<'PYTEST'
import sys, pathlib, collections
root=pathlib.Path(sys.argv[1]); rows=[]
for line in (root/'ui/menus.tsv').read_text().splitlines():
 if not line or line.startswith('#'):continue
 p,code,label,i=line.split('|'); rows.append((p,code,label,i))
assert len(rows)>=470
assert len({i for _,_,_,i in rows}) == len(rows)
assert [r[2] for r in rows if r[0]=='root'] == ['安装虚拟显示器','管理显示与分辨率','安装桌面环境','管理桌面与会话','安装 RustDesk','更新 RustDesk','RustDesk 连接配置','更新 HDM 管理器','智能安装与续装','系统诊断与日志']
assert not any('实验' in s or 'Preview' in s for _,_,s,_ in rows)
assert 'hdm_open_after_install' in (root/'install.sh').read_text()
assert '[[ -t 0 && -t 1' in (root/'install.sh').read_text()
PYTEST
# Root and nested menus share the same compact numbered formatting.
[[ $output == *"HDM v$(cat "$ROOT/VERSION")"* && $output == *'0 / q 退出'* ]]
[[ $output == *'请选择 > '* ]]
nested=$(printf '1\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $nested == *'安装 Xorg Dummy'* && $nested == *'安装 Xvfb'* ]]
[[ $nested == *'0 返回    q 退出'* && $nested == *'请选择 > '* ]]
echo 'PASS Baota-style compact menu, 2-column/1-column layouts, nested navigation and auto-open guard'
