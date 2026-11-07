import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
p = subprocess.run(['python3', str(root/'modules/diagnostics/status_json.py')],
                   capture_output=True, text=True, check=True)
value = json.loads(p.stdout)
assert value['schema'] == 1
assert value['hdm_version'] == (root/'VERSION').read_text().strip()
assert isinstance(value['sessions'], list)
assert value['gnome']['remote_picture_captured'] == 'not_tested'
assert value['rustdesk']['authentication'] == 'not_tested'
for forbidden in ('password', 'RustDesk.toml', 'private_key', 'auth_token'):
    assert forbidden not in p.stdout
p2 = subprocess.run(['bash', str(root/'hdm.sh'), '--status-json'],
                    capture_output=True, text=True, check=True)
assert json.loads(p2.stdout)['hdm_version'] == value['hdm_version']
print('PASS read-only JSON diagnostics')
