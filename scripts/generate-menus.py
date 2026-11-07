#!/usr/bin/env python3
"""Development-only generator: exact 440+ nested menu entries from approved spec."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
text = (root / 'docs/AI_DEVELOPMENT_SPEC.md').read_text(encoding='utf-8')
sections = text.split('### 2.1 ')[1].split('### 2.11 ')[0]
main = [
 ('1','安装虚拟显示器 — Xorg Dummy / Xvfb / VKMS'),
 ('2','管理 / 更新虚拟显示器 — 分辨率 / 驱动 / 切换'),
 ('3','安装桌面环境 — GNOME(默认) / XFCE / MATE'),
 ('4','管理 / 更新桌面环境 — 更新 / 会话 / 切换'),
 ('5','安装 RustDesk 客户端 — 架构 / 版本 / 软件源'),
 ('6','更新 RustDesk 客户端 — 更新 / 回滚'),
 ('7','配置 ID / 中继服务器 — 地址 / 公钥 / 密码'),
 ('8','更新管理脚本 — GitHub Releases'),
 ('9','一键安装推荐组合 — GNOME + Dummy + RustDesk'),
 ('10','系统检测 / 故障修复 — 黑屏 / 服务 / 软件源'),
]
rows = [('root', key, label, key) for key,label in main]
last = ''
for line in sections.splitlines():
    n = re.match(r'^\s+(\d+(?:\.\d+){1,3})\s+(.+?)\s*$', line)
    if n:
        ident, label = n.groups()
        parent, code = ident.rsplit('.', 1)
        rows.append((parent, code, label.replace('|','/'), ident))
        last = ident
    else:
        letter = re.match(r'^\s+([A-G])\.\s+(.+?)\s*$', line)
        if letter and last and last.count('.') >= 2:
            l,label = letter.groups()
            rows.append((last, l, label.replace('|','/'), f'{last}.{l}'))
# ensure no duplicate ID
assert len({r[3] for r in rows})==len(rows), 'menu IDs duplicated'
output = root / 'ui/menus.tsv'
# Display labels are intentionally concise; retain curated wording when regenerating
# the menu tree from the original functional specification.
if output.is_file():
    existing = {}
    for line in output.read_text(encoding='utf-8').splitlines():
        data = line.split('|')
        if len(data) == 4 and data[0] != '# parent':
            existing[data[3]] = data[2]
    original_rows = [tuple(line.split('|')) for line in output.read_text(encoding='utf-8').splitlines()
                     if line and not line.startswith('#')]
    generated_ids = {ident for _, _, _, ident in rows}
    rows = [(parent, code, existing.get(ident, label), ident) for parent, code, label, ident in rows]
    # Retain implemented menu additions that were made after the original spec.
    rows.extend((parent, code, label, ident) for parent, code, label, ident in original_rows
                if ident not in generated_ids)
output.write_text('# parent|selection|label|action_id\n' + ''.join('|'.join(row)+'\n' for row in rows),encoding='utf-8')
print(f'Generated {len(rows)} menu items, including {len(main)} main menu entries')
