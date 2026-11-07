import json
import os
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
parser = root / 'core/release_parser.py'
sha = 'a' * 64
asset = {
    'name': 'rustdesk-1.5.1-x86_64.deb',
    'digest': 'sha256:' + sha,
    'browser_download_url': 'https://github.com/rustdesk/rustdesk/releases/download/1.5.1/rustdesk-1.5.1-x86_64.deb',
}
items = [
    {'tag_name': 'nightly', 'assets': [asset]},
    {'tag_name': '1.5.1', 'assets': [asset], 'draft': False, 'prerelease': False},
    {'tag_name': '1.9.9', 'assets': [{**asset, 'digest':'no-digest'}]},
]
with tempfile.TemporaryDirectory() as temp:
    path = pathlib.Path(temp) / 'release.json'
    path.write_text(json.dumps(items), encoding='utf-8')
    ok = subprocess.run(['python3', str(parser), 'rustdesk', 'latest', 'x86_64', str(path)],capture_output=True,text=True)
    assert ok.returncode == 0, ok.stderr
    assert ok.stdout.startswith('1.5.1\t'), ok.stdout
    assert sha in ok.stdout
    # Ubuntu 26 ARM64 must select the native aarch64 asset, never x86_64.
    arm_asset = {**asset,
        'name':'rustdesk-1.5.1-aarch64.deb',
        'browser_download_url':'https://github.com/rustdesk/rustdesk/releases/download/1.5.1/rustdesk-1.5.1-aarch64.deb'}
    path.write_text(json.dumps([{**items[1], 'assets':[asset,arm_asset]}]), encoding='utf-8')
    arm = subprocess.run(['python3', str(parser), 'rustdesk', 'latest', 'aarch64', str(path)],capture_output=True,text=True)
    assert arm.returncode == 0 and 'aarch64.deb' in arm.stdout and 'x86_64.deb' not in arm.stdout
    poison = [{**items[1], 'assets': [{**asset, 'browser_download_url': 'https://attacker.example/pkg.deb'}]}]
    path.write_text(json.dumps(poison),encoding='utf-8')
    bad = subprocess.run(['python3', str(parser), 'rustdesk', 'latest', 'x86_64', str(path)],capture_output=True,text=True)
    assert bad.returncode != 0
    hdm = {'tag_name':'mirror-2026-11','draft':False,'prerelease':False,'assets':[]}
    path.write_text(json.dumps([hdm]),encoding='utf-8')
    bad = subprocess.run(['python3', str(parser), 'hdm', 'latest', 'x86_64', str(path)],capture_output=True,text=True)
    assert bad.returncode != 0
print('PASS release parser')
