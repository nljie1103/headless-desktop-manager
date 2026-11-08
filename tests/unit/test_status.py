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
# The real installer creates a root-only HDM_STATE directory. An unprivileged
# diagnostic must remain readable and mark rollback status unknown, not crash.
sys.path.insert(0, str(root/'modules/diagnostics'))
import status_json
from unittest.mock import patch
with patch.object(pathlib.Path, 'is_file', side_effect=PermissionError('root-only state')):
    assert status_json.rollback_marker_state('/var/lib/hdm') is None
assert status_json.rollback_marker_state('/definitely/nonexistent/hdm-state') is False
# SSH sessions do not count as graphical; scan all 30, no false 24-row cap.
def mock_logind(*args, **kwargs):
    if args[:2] == ('loginctl', 'list-sessions'):
        return 0, '\n'.join(f"c{i} {i} user seat0" for i in range(30))
    if args[:2] == ('loginctl', 'show-session'):
        return 0, "Type=x11\nDesktop=xfce\nState=active\nClass=user"
    return 127, ''
with patch.object(status_json, 'run', side_effect=mock_logind):
    found, truncated = status_json.sessions()
assert len(found) == 30 and truncated is False
assert found[0]['id'] == 'c0' and found[-1]['id'] == 'c29'

def mock_ssh_logind(*args, **kwargs):
    if args[:2] == ('loginctl', 'list-sessions'):
        return 0, '\n'.join(f'{i} 1001 ubuntu - {i} user - no -' for i in range(75))
    if args[:2] == ('loginctl', 'show-session'):
        return 0, 'Type=tty\nDesktop=\nState=online\nClass=user\nName=ubuntu'
    return 127, ''
with patch.object(status_json, 'run', side_effect=mock_ssh_logind):
    found, truncated = status_json.sessions()
assert found == [] and truncated is False
print('PASS read-only JSON diagnostics and root-only rollback-state handling')
