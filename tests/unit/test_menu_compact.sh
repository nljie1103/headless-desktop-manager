#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"

output=$(printf '0\n' | COLUMNS=100 bash "$ROOT/hdm.sh")
[[ $output == *'1. 快速部署'* && $output == *'4. RustDesk 远程控制'* ]]
[[ $output == *'6. HDM 管理'* && $output == *'3. 登录管理器'* ]]
[[ $output != *'图形协议管理'* && $output != *'高级会话工具'* ]]
[[ $output != *'会话数量超限'* && $output == *'登录界面：'* ]]
output=$(printf '0\n' | COLUMNS=54 bash "$ROOT/hdm.sh")
[[ $output == *'1.  快速部署'* && $output == *'6.  HDM 管理'* ]]
python3 - "$ROOT" <<'PYTEST'
import pathlib,sys
root=pathlib.Path(sys.argv[1])
rows=[line.split('|') for line in (root/'ui/menus.tsv').read_text().splitlines() if line and not line.startswith('#')]
assert len(rows)<=80 and len({r[3] for r in rows}) == len(rows)
assert [r[2] for r in rows if r[0]=='root'] == [
    '快速部署','桌面环境','登录管理器（LightDM / GDM3 选一个）',
    'RustDesk 远程控制','显示设置（有画面则无需安装虚拟显示）','HDM 管理']
assert max(r[3].count('.') for r in rows)<=2
assert not any('高级协议诊断' in r[2] or '高级工具' in r[2] for r in rows)
assert 'hdm_open_after_install' in (root/'install.sh').read_text()
PYTEST
[[ $output == *"HDM v$(cat "$ROOT/VERSION")"* && $output == *'0/q 退出'* ]]
nested=$(printf '1\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $nested == *'安装 / 补齐桌面和 RustDesk'* && $nested == *'查看推荐安装计划'* ]]
[[ $nested == *'0/q 返回    Q 退出'* ]]
[[ $(grep -c 'HDM 管理' <<< "$nested") -ge 2 ]]
dm_menu=$(printf '3\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $dm_menu == *'启动当前登录管理器'* && $dm_menu == *'启用开机自启'* ]]
[[ $dm_menu == *'卸载 GDM3'* && $dm_menu == *'卸载 LightDM'* ]]
desktop_menu=$(printf '2\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $desktop_menu == *'安装 XFCE（X11 推荐）'* ]]
[[ $desktop_menu == *'图形会话与协议'* ]]
session_menu=$(printf '2\n9\nq\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $session_menu == *'结束指定图形用户会话'* && $session_menu == *'选择 LightDM 默认 X11 桌面'* ]]
rustdesk_menu=$(printf '4\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $rustdesk_menu == *'安装 RustDesk'* && $rustdesk_menu == *'启动 RustDesk'* ]]
[[ $rustdesk_menu == *'查看设备 ID'* && $rustdesk_menu == *'禁用开机自启'* ]]
script_menu=$(printf '6\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $script_menu == *'更新 HDM（最新正式版）'* ]]
echo 'PASS compact task-first menu and direct service controls'
