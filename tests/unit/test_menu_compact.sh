#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
export HDM_ETC="$TMP/etc" HDM_STATE="$TMP/state" HDM_CACHE="$TMP/cache" HDM_LOG_DIR="$TMP/log"

output=$(printf '0\n' | COLUMNS=100 bash "$ROOT/hdm.sh")
[[ $output == *'1. 显示输出'* && $output == *'4. 桌面环境'* ]]
[[ $output == *'8. HDM 管理'* && $output == *'3. 图形协议'* ]]
[[ $output != *'图形协议管理'* && $output != *'高级会话工具'* ]]
[[ $output != *'会话数量超限'* && $output == *'登录界面：'* ]]
[[ $output == *'七节点桌面依赖线轴'* ]]
[[ $output == *'显示输出'* && $output == *'登录管理器'* && $output == *'图形协议'* ]]
[[ $output == *'桌面环境'* && $output == *'图形会话'* && $output == *'设备 ID'* ]]
[[ $output != *'必需软件包：缺失'* ]]
[[ $output != *'目标：XFCE'* && $output != *'[已安装] XFCE 会话'* ]]
[[ $output != *'绿=本地通过'* && $output != *'●=本地通过'* ]]
[[ $output != *'本机检测不代表 RustDesk'* && $output != *'软件已装不代表服务已运行'* ]]
[[ $output == *'RustDesk'* ]]
output=$(printf '0\n' | COLUMNS=54 bash "$ROOT/hdm.sh")
[[ $output == *'1.  显示输出'* && $output == *'8.  HDM 管理'* ]]
python3 - "$ROOT" <<'PYTEST'
import pathlib,sys
root=pathlib.Path(sys.argv[1])
rows=[line.split('|') for line in (root/'ui/menus.tsv').read_text().splitlines() if line and not line.startswith('#')]
assert len(rows)<=80 and len({r[3] for r in rows}) == len(rows)
assert [r[2] for r in rows if r[0]=='root'] == [
    '显示输出','登录管理器','图形协议','桌面环境',
    '图形会话','RustDesk','设备 ID','HDM 管理']
assert max(r[3].count('.') for r in rows)<=2
assert not any('高级协议诊断' in r[2] or '高级工具' in r[2] for r in rows)
assert 'hdm_open_after_install' in (root/'install.sh').read_text()
PYTEST
[[ $output == *"HDM v$(cat "$ROOT/VERSION")"* && $output == *'0/q 退出'* ]]
nested=$(printf '8\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $nested == *'快速部署 / 补齐缺失组件'* && $nested == *'查看推荐安装计划'* ]]
[[ $nested == *'0/q 返回    Q 退出'* ]]
[[ $(grep -c 'HDM 管理' <<< "$nested") -ge 2 ]]
dm_menu=$(printf '2\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $dm_menu == *'启动登录管理器'* && $dm_menu == *'启用开机自启'* ]]
[[ $dm_menu == *'卸载 GDM3'* && $dm_menu == *'卸载 LightDM'* ]]
desktop_menu=$(printf '4\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $desktop_menu == *'安装 XFCE'* ]]
[[ $(grep '^4|' "$ROOT/ui/menus.tsv") != *'图形会话'* ]]
session_menu=$(printf '5\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $session_menu == *'结束指定图形会话'* && $session_menu == *'新建登录入口'* ]]
rustdesk_menu=$(printf '6\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $rustdesk_menu == *'安装 RustDesk'* && $rustdesk_menu == *'启动 RustDesk'* ]]
[[ $rustdesk_menu == *'设置 RustDesk 密码'* && $rustdesk_menu == *'禁用开机自启'* ]]
[[ $rustdesk_menu == *'访问权限管理'* && $rustdesk_menu == *'权限灰色 / 授权诊断'* ]]
script_menu=$(printf '8\n0\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $script_menu == *'更新 HDM（最新正式版）'* ]]
protocol_menu=$(printf '3\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $protocol_menu == *'X11 / Wayland / Xorg 状态'* ]]
[[ $protocol_menu == *'选择 XFCE / MATE 的 X11 会话'* ]]
[[ $protocol_menu == *'选择 GNOME Wayland'* ]]
id_menu=$(printf '7\nq\n0\n' | COLUMNS=92 bash "$ROOT/hdm.sh")
[[ $id_menu == *'查看设备 ID'* && $id_menu == *'自建 ID / 中继服务器'* ]]
echo 'PASS compact task-first menu and direct service controls'
