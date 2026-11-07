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
