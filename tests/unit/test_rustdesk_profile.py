#!/usr/bin/env python3
"""Ensure atomic native RustDesk2.toml edits never clobber unrelated settings."""
import importlib.util
from pathlib import Path
import os
import stat
import tempfile

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rustconfig', root/'scripts/rustdesk_config.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
expected = {'id': 'rd.example.test:10010', 'relay': 'rd.example.test:10011', 'key': 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123='}
with tempfile.TemporaryDirectory() as tmp:
    file=Path(tmp)/'home'/'rustdesk'/'RustDesk2.toml'
    file.parent.mkdir(parents=True)
    file.write_text("rendezvous_server = 'public.example.test'\nnat_type = 1\n\n[options]\ncustom-rendezvous-server = 'old.example.test'\nrelay-server = 'oldrelay.example.test'\nkey = 'oldkey'\ndirect-server = 'Y'\n\n[other]\nkeep = 42\n",encoding='utf-8')
    m.patch_file(str(file), expected, os.getuid(), os.getgid())
    cfg=m.load(file)
    assert m.fields(cfg)==(expected['id'],expected['relay'],expected['key'])
    assert cfg['rendezvous_server']==expected['id']
    assert cfg['nat_type']==1 and cfg['options']['direct-server']=='Y'
    assert cfg['other']['keep']==42
    assert stat.S_IMODE(file.stat().st_mode)==0o600
    before=file.read_bytes()
    m.patch_file(str(file), expected, os.getuid(), os.getgid())
    assert file.read_bytes()==before
    file.write_text('[options]\nbroken = [not-a-valid-toml\n',encoding='utf-8')
    before=file.read_bytes()
    try: m.patch_file(str(file),expected,os.getuid(),os.getgid())
    except Exception: pass
    else: raise AssertionError('must reject invalid TOML')
    assert file.read_bytes()==before
    file.unlink()
    link=Path(tmp)/'symlink'
    link.symlink_to(file.parent)
    try: m.patch_file(str(link/'RustDesk2.toml'),expected,os.getuid(),os.getgid())
    except ValueError: pass
    else: raise AssertionError('must reject symlinked directories')
    try: m.patch_file(str(file),expected,os.getuid(),os.getgid())
    except Exception: raise
    assert m.fields(m.load(file)) == (expected['id'],expected['relay'],expected['key'])
print('PASS profile scope native patch / readback / unrelated keys / invalid TOML / symlinks')
