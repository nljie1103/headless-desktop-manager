"""Pure diagnostic planning tests - no real services or network required."""
import importlib.util
import json
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(root / 'modules/diagnostics'))
import doctor
import status_json

config = '''# WaylandEnable=false
[security]
WaylandEnable=false
[daemon]
#WaylandEnable=false
WaylandEnable = true
'''.splitlines()
assert not status_json.gdm_x11_enabled(config)
assert status_json.gdm_x11_enabled(config + ['WaylandEnable = false # managed'])
assert not status_json.gdm_x11_enabled(config + ['WaylandEnable=false', 'WaylandEnable=true'])

report = {
    'system': {'id': 'ubuntu', 'version_id':'24.04', 'architecture':'x86_64'},
    'hdm_version': '0.3.0',
    'packages': {p:{'installed': True} for p in ('xserver-xorg-video-dummy', 'ubuntu-desktop','gnome-shell','rustdesk')},
    'display': {'hdm_dummy_config_present':True, 'gdm3_service':'active',
        'gdm_x11_config_present':True, 'x11_socket_paths':['X0']},
    'gnome':{'active_gnome_x11_user_session_detected':True},
    'rustdesk':{'service':'active'}, 'rollback_pending':False,
}
checks = doctor.inspect(report)
assert all(c['level'] == 'ok' for c in checks[:-1])
assert checks[-1]['code'] == 'remote_validation' and checks[-1]['level'] == 'manual'
report['display']['gdm_x11_config_present'] = False
report['rustdesk']['service'] = 'failed'
report['rollback_pending'] = True
checks = doctor.inspect(report)
assert any(c['code'] == 'gdm_x11' and c['next_action'] == '菜单 3.1.5' for c in checks)
assert any(c['code'] == 'rustdesk_service' and c['level'] == 'action' for c in checks)
assert any(c['code'] == 'rollback' and c['level'] == 'warning' for c in checks)
report['rollback_pending'] = None
checks = doctor.inspect(report)
assert any(c['code'] == 'rollback' and c['level'] == 'warning' and
           'sudo hdm --doctor' in c['next_action'] for c in checks)
modern = {
    'system': {'id':'ubuntu', 'version_id':'26.04', 'architecture':'aarch64'},
    'packages': {p:{'installed': True, 'version':'50.0'} for p in
                 ('ubuntu-desktop', 'gnome-shell', 'gdm3', 'rustdesk', 'pipewire',
                  'xdg-desktop-portal', 'xdg-desktop-portal-gnome')},
    'display': {'gdm3_service':'active', 'gdm_x11_config_present':False},
    'gnome':{'active_gnome_wayland_user_session_detected':True},
    'rustdesk':{'service':'active'}, 'rollback_pending':False
}
assert doctor.gnome_wayland_only(modern['system'], modern['packages'])
checks_modern = doctor.inspect(modern)
assert not any(c['code'] in ('gdm_x11', 'dummy_package', 'dummy_config') for c in checks_modern)
assert any(c['code']=='gnome_session' and c['level']=='ok' for c in checks_modern)
assert any(c['code']=='remote_validation' and c['level']=='manual' for c in checks_modern)
assert not doctor.gnome_wayland_only(report['system'], report['packages'])
# A modern Ubuntu host with XFCE/X11 must not be diagnosed as missing GNOME.
xfce = {
    'system': {'id':'ubuntu','version_id':'26.04','architecture':'aarch64'},
    'packages': {p:{'installed':True,'version':'1.0'} for p in
                 ('xfce4-session','xfce4','lightdm','xserver-xorg-core','rustdesk')},
    'display': {'lightdm_service':'active','gdm3_service':'inactive','x11_socket_paths':['X0']},
    'sessions': [{'type':'x11','desktop':'xfce','state':'active','class':'user'}],
    'gnome': {},'rustdesk':{'service':'active'},'rollback_pending':False,
}
assert doctor.x11_desktop(xfce) == 'XFCE'
xfce_checks = doctor.inspect(xfce)
assert any(c['code']=='x11_user_session' and c['level']=='ok' for c in xfce_checks)
assert any(c['code']=='lightdm' and c['level']=='ok' for c in xfce_checks)
assert not any(c['code'] in ('gnome_package','gdm_service','gnome_session','display_stack') for c in xfce_checks)
assert xfce_checks[-1]['code']=='remote_validation' and xfce_checks[-1]['level']=='manual'
# Installed XFCE alone does not trump an actively logged-in GNOME Wayland user.
gnome_active = dict(xfce)
gnome_active['sessions'] = [{'type':'wayland','desktop':'gnome','state':'active','class':'user'}]
assert doctor.x11_desktop(gnome_active) is None
result = subprocess.run(['python3', str(root/'modules/diagnostics/doctor.py'), '--json'],
                        text=True, capture_output=True, check=True)
actual = json.loads(result.stdout)
assert 'findings' in actual and actual['actual_remote_connection_verified'] is False
for secret in ('password', 'RustDesk2.toml', 'private_key', 'auth_token'):
    assert secret not in result.stdout
# Even when invoked as root, --doctor and --quick-status must not create HDM directories.
import os
from tempfile import TemporaryDirectory
with TemporaryDirectory() as tmp:
    env = {**os.environ, 'HDM_ETC': tmp+'/etc', 'HDM_STATE':tmp+'/state',
           'HDM_CACHE':tmp+'/cache', 'HDM_LOG_DIR':tmp+'/log'}
    subprocess.run(['bash', str(root/'hdm.sh'), '--doctor'], env=env, check=True, capture_output=True, text=True)
    subprocess.run(['bash', str(root/'hdm.sh'), '--quick-status'], env=env, check=True, capture_output=True, text=True)
    for directory in ('etc','state','cache','log'):
        assert not (Path(tmp)/directory).exists(), 'read-only CLI mutated filesystem'
print('PASS pure doctor rule engine, GDM parser, JSON and read-only checks')
