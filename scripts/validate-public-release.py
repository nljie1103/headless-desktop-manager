#!/usr/bin/env python3
"""Validate public release copy; never accept publishing internals as user changes."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = re.compile(
    r"Windows|PowerShell|GitHub Actions|CI/CD|自动推送|自动上传|上传脚本|"
    r"触发Release|推送标签|git push|推送.*[Tt]ag|版本标签触发|发布工作流|"
    r"内部发布流程|打标签|编译发布流程", re.IGNORECASE
)

def check_release(version, title_path, notes_path):
    title = (ROOT / title_path).read_text(encoding='utf-8').strip()
    notes = (ROOT / notes_path).read_text(encoding='utf-8').strip()
    assert re.fullmatch(rf"v{re.escape(version)} · [^\n]{{4,100}}", title), f'invalid release title: {title!r}'
    assert len(notes) >= 90, f'release notes too short: {notes_path}'
    assert len(re.findall(r'^- ', notes, re.M)) >= 2, 'release notes must have meaningful bullet changes'
    assert not re.search(r'^#{1,6}\s', notes, re.M), 'release body must not repeat a title as a heading'
    assert title not in notes, 'release body duplicates release title'
    assert not re.search(rf'(?<![\w.])v{re.escape(version)}(?![\w.])', notes), 'version repeated in release body'
    assert not INTERNAL.search(title + '\n' + notes), f'internal publishing details in public notes: {notes_path}'


def main():
    version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
    assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'VERSION must be semantic 3-part version'
    summary = (ROOT / 'release/COMMIT_SUMMARY.txt').read_text(encoding='utf-8').strip()
    assert len(summary) >= 12 and '\n' not in summary and not summary.startswith(('v', 'V')), 'invalid commit summary'
    assert not INTERNAL.search(summary), 'commit summary exposes internal publishing operations'
    check_release(version, 'release/RELEASE_TITLE.txt', 'release/RELEASE_NOTES.md')
    check_release('0.3.4','release/history/v0.3.4/RELEASE_TITLE.txt','release/history/v0.3.4/RELEASE_NOTES.md')
    workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
    assert 'test "v$(cat VERSION)" = "${GITHUB_REF_NAME}"' in workflow
    assert '--notes-file release/RELEASE_NOTES.md' in workflow
    assert '--title "$title"' in workflow
    assert 'gh release edit v0.3.4' in workflow
    print('PASS: version, tag rule, public title and separate notes, commit summary, legacy metadata')

if __name__ == '__main__':
    try: main()
    except (AssertionError,OSError) as exc:
        print('INVALID PUBLIC RELEASE:', exc, file=sys.stderr)
        sys.exit(1)
