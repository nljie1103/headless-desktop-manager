"""Non-destructive publish artifact tests. Windows PowerShell behavior remains unverified."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
ps = (root / 'tools/publish-windows.ps1').read_bytes()
assert ps.startswith(b'\xef\xbb\xbf'), 'PowerShell 5.1 requires BOM for UTF-8 scripts'
s = ps.decode('utf-8-sig')
assert 'Read-Host' not in s, 'Publisher must not prompt YES or ask user to type commit'
assert 'git push --force' not in s and "'--force'" not in s
assert 'Invoke-Git -Arguments' in s
assert "'--no-pager', 'diff'" in s, 'Git pager can hang CMD at colon prompt'
assert "'HEAD:refs/heads/main'" in s
assert 'Publish-VersionTag' in s and "'refs/tags/'" in s
assert 'release\\COMMIT_SUMMARY.txt' in s
assert "[version]$version -lt [version]$remoteVersion" in s
v = (root / 'VERSION').read_text().strip()
assert re.fullmatch(r'\d+\.\d+\.\d+', v)
summary = (root / 'release/COMMIT_SUMMARY.txt').read_text().strip()
assert len(summary) >= 12 and not summary.lower().startswith('v0.')
assert (root / 'CHANGELOG.md').read_text().find('v' + v) >= 0
cmd = (root / 'tools/上传到GitHub-双击运行.cmd').read_text()
assert f'headless-desktop-manager-v{v}.zip' in cmd
assert (root / '.gitattributes').read_text().find('*.sh text eol=lf') >= 0
readme = (root / 'README.md').read_text()
assert 'Linux 无显示器远程桌面' in readme[:500]
assert 'README.en.md' in readme
print('PASS publisher version, BOM, no prompts, README, commit summary, LF rules')
