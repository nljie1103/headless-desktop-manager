#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"
output=$(printf '0\n' | COLUMNS=100 bash "$ROOT/hdm.sh")
[[ $output == *'1. 显示输出管理'* && $output == *'5. 图形会话管理'* ]]
[[ $output == *'8. HDM 脚本管理'* && $output != *'快速入口'* && $output != *'实验'* ]]
[[ $output != *'建议：'* && $output == *'登录管理器'* && $output == *'设备 ID'* ]]
output=$(printf '0\n' | COLUMNS=54 bash "$ROOT/hdm.sh")
[[ $output == *'1.  显示输出管理'* && $output == *'8.  HDM 脚本管理'* ]]
python3 - "$ROOT" <<'PYTEST'
import sys, pathlib, collections
root=pathlib.Path(sys.argv[1]); rows=[]
for line in (root/'ui/menus.tsv').read_text().splitlines():
 if not line or line.startswith('#'):continue
 p,code,label,i=line.split('|'); rows.append((p,code,label,i))
assert len(rows)>=570
assert len({i for _,_,_,i in rows}) == len(rows)
assert [r[2] for r in rows if r[0]=='root'] == ['显示输出管理','登录管理器管理','图形协议管理','桌面环境管理','图形会话管理','RustDesk 管理','设备 ID 与设备信息','HDM 脚本管理']
assert not any('实验' in s or 'Preview' in s for _,_,s,_ in rows)
assert 'hdm_open_after_install' in (root/'install.sh').read_text()
assert '[[ -t 0 && -t 1' in (root/'install.sh').read_text()
PYTEST
# Root and nested menus share the same compact numbered formatting.
[[ $output == *"HDM v$(cat "$ROOT/VERSION")"* && $output == *'0 / q 退出'* ]]
[[ $output == *'请选择 > '* ]]
nested=$(printf '1\n1\n0\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $nested == *'安装 Xorg Dummy'* && $nested == *'安装 Xvfb'* ]]
[[ $nested == *'0 返回    q 退出'* && $nested == *'请选择 > '* ]]
dm_uninstall=$(printf '2\n2\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $dm_uninstall == *'1.   卸载 GDM3'* && $dm_uninstall == *'2.   卸载 LightDM'* ]]
[[ $dm_uninstall != *'预览 GDM3'* && $dm_uninstall != *'须先启用 LightDM'* ]]
desktop_install=$(printf '4\n1\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $desktop_install == *'2.   安装 XFCE + Xorg + LightDM'* ]]
rustdesk_root=$(printf '6\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $rustdesk_root == *'1.   安装 RustDesk'* && $rustdesk_root == *'2.   卸载 RustDesk'* ]]
[[ $rustdesk_root == *'3.   更新 RustDesk'* ]]
script_root=$(printf '8\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $script_root == *'1.   更新 HDM（最新正式版）'* ]]
[[ $script_root != *'2.   安装正式 Release'* && $script_root != *'5.   从 main 更新'* ]]
echo 'PASS compact direct install/remove/update menus, original chain and nested navigation'
