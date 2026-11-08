"""Current v5 architecture contract, replacing the obsolete ten-menu spec."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
lines = (root / 'ui/menus.tsv').read_text(encoding='utf-8').splitlines()
rows = [line.split('|') for line in lines if line and not line.startswith('#')]
assert 50 <= len(rows) <= 80
assert [r[2] for r in rows if r[0] == 'root'] == [
    '显示输出', '登录管理器', '图形协议', '桌面环境',
    '图形会话', 'RustDesk', '设备 ID', 'HDM 管理']
assert '7|12|设置权限诊断' in (root/'ui/legacy-menus.tsv').read_text(encoding='utf-8')
for required in ('docs/architecture.md', 'docs/menu-guide.md', 'docs/development.md',
                 'scripts/build-menus-v2.py', 'templates/systemd/hdm-recovery.service',
                 'templates/systemd/hdm-recovery.timer', 'ui/actions.sh', 'ui/actions_v2.sh'):
    assert (root/required).is_file(), required
assert (root/'config/github-endpoints.conf').read_text(encoding='utf-8').count('nljie1103') >= 3
for obsolete in ('docs/AI_DEVELOPMENT_SPEC.md', 'scripts/generate-menus.py',
                 'README.zh-CN.md', 'packages', 'adapters', 'bootstrap'):
    assert not (root/obsolete).exists(), obsolete
print('PASS v5 eight-section architecture, essential compatibility and no placeholder assets')
