#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import tempfile

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rd_perms', root/'scripts/rustdesk_permissions.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp)/'cfg'/'RustDesk2.toml'
    path.parent.mkdir()
    path.write_text("rendezvous_server = 'example.test'\n[options]\ncustom-rendezvous-server = 'example.test'\nallow-remote-config-modification = 'N'\nother-setting = 'kept'\n")
    mod.update(str(path), mod.profile_settings('custom', 'N'), os.getuid(), os.getgid())
    text = path.read_text()
    assert "other-setting = 'kept'" in text and "custom-rendezvous-server = 'example.test'" in text
    assert 'access-mode = "custom"' in text
    mod.update(str(path), mod.profile_settings('full', 'N'), os.getuid(), os.getgid())
    assert 'access-mode = "full"' in path.read_text()
    mod.update(str(path), mod.profile_settings('view', 'N'), os.getuid(), os.getgid())
    assert 'access-mode = "view"' in path.read_text()
    mod.update(str(path), {'access-mode': 'custom', 'enable-file-transfer': 'N'}, os.getuid(), os.getgid())
    mod.update(str(path), mod.toggle_settings('enable-keyboard', 'Y'), os.getuid(), os.getgid())
    assert 'enable-file-transfer = "N"' in path.read_text()
    mod.update(str(path), mod.toggle_settings('enable-keyboard', 'N'), os.getuid(), os.getgid())
    assert 'enable-keyboard = "N"' in path.read_text()
    assert 'enable-file-transfer = "N"' in path.read_text()
    mod.update(str(path), mod.toggle_settings('allow-remote-config-modification', 'Y'), os.getuid(), os.getgid())
    for flag, value in (('hidden-setting', 'Y'), ('enable-keyboard','maybe'), ('','N')):
        try: mod.toggle_settings(flag, value)
        except ValueError: pass
        else: raise AssertionError('invalid toggle was accepted')
    mod.update(str(path), mod.profile_settings('custom', 'Y'), os.getuid(), os.getgid())
    assert 'allow-remote-config-modification = "Y"' in path.read_text()
    mod.update(str(path), {'approve-mode':'password','verification-method':'use-permanent-password'}, os.getuid(), os.getgid())
    assert 'approve-mode = "password"' in path.read_text()
    original = path.read_text()
    path.write_text('[options\ninvalid')
    try:
        mod.update(str(path), mod.profile_settings('view'), os.getuid(), os.getgid())
    except ValueError:
        pass
    else:
        raise AssertionError('invalid TOML accepted')
    path.unlink()
    target = Path(temp)/'outside'
    target.write_text(original)
    path.symlink_to(target)
    try:
        mod.update(str(path), mod.profile_settings('view'), os.getuid(), os.getgid())
    except ValueError:
        pass
    else:
        raise AssertionError('symlink accepted')
    assert target.read_text()==original
print('PASS RustDesk permissions modes, remote config, auth, safety')
