#!/usr/bin/env python3
import pathlib, tempfile, subprocess, tarfile
root=pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as d:
    p=pathlib.Path(d)
    log=p/'logs'; log.mkdir()
    (log/'operation-test.log').write_text('Step unpack\nSetting up rustdesk\npassword: wrongtest\nserver-key=topsecretAAAAAAAAAAAAAAAAA\n')
    (log/'operation-fail.log').write_text('No space left on device\n')
    (log/'skip.log').symlink_to('/etc/passwd')
    cmd=['python3',str(root/'scripts/export_diagnostics.py'),'--output-dir',str(p/'out'),'--hdm-log-dir',str(log)]
    out=subprocess.run(cmd,check=True,capture_output=True,text=True,timeout=80)
    archive=pathlib.Path(out.stdout.strip())
    assert archive.is_file() and archive.stat().st_mode & 0o077 == 0
    with tarfile.open(archive) as tar:
        names=tar.getnames()
        assert 'hdm/operation-test.log' in names
        assert 'hdm/operation-fail.log' in names
        assert 'hdm/skip.log' not in names
        data=tar.extractfile('hdm/operation-test.log').read().decode()
        assert 'Setting up rustdesk' in data and 'wrongtest' not in data and 'topsecret' not in data
print('PASS diagnostic archive redaction, operation history, symlink refusal')
