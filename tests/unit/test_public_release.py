"""Guard against internal publishing details and duplicated release titles."""
from pathlib import Path
import importlib.util

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('releasecheck', root/'scripts/validate-public-release.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.main()
assert mod.INTERNAL.search('Windows上传自动推送版本标签触发Release构建')
assert mod.INTERNAL.search('PowerShell')
assert mod.INTERNAL.search('GitHub Actions')
assert not mod.INTERNAL.search('预览版更新前校验归档并保留旧版以便回滚')
assert 'v0.3.5' not in (root/'release/RELEASE_NOTES.md').read_text()
workflow = (root/'.github/workflows/release.yml').read_text()
assert 'gh release view "$GITHUB_REF_NAME"' in workflow
assert 'gh release upload "$GITHUB_REF_NAME"' in workflow and '--clobber' in workflow

print('PASS: public release copy policy')
