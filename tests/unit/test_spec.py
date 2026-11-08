import pathlib
root=pathlib.Path(__file__).resolve().parents[2]
spec=(root/'docs/AI_DEVELOPMENT_SPEC.md').read_text(encoding='utf-8')
menus=(root/'ui/menus.tsv').read_text(encoding='utf-8')
assert 40 <= len([x for x in menus.splitlines() if x and not x.startswith('#')]) <= 80
assert 'root|4|RustDesk 远程控制|4' in menus
assert '7|12|设置权限诊断' in (root/'ui/legacy-menus.tsv').read_text(encoding='utf-8')
for word in ['GNOME','Xorg Dummy','Xvfb','VKMS','RustDesk','nljie1103/headless-desktop-manager']:
    assert word in spec, word
assert (root/'config/github-endpoints.conf').read_text().count('nljie1103')>=3
assert (root/'packages/manifests/ubuntu-24.04-amd64.tsv').read_text().count('https://github.com')==0
print('PASS spec')
