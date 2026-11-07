import io
import pathlib
import subprocess
import tarfile
import tempfile

root=pathlib.Path(__file__).resolve().parents[2]
script=root/'core/verify_archive.py'
with tempfile.TemporaryDirectory() as td:
    for case in ('ok','traversal','symlink'):
        file=pathlib.Path(td)/f'{case}.tar.gz'
        with tarfile.open(file,'w:gz') as archive:
            item=tarfile.TarInfo('headless-desktop-manager/VERSION' if case!='traversal' else '../../etc/passwd')
            if case=='symlink':
                item.type=tarfile.SYMTYPE
                item.linkname='/etc/passwd'
                archive.addfile(item)
            else:
                data=b'0.1.0\n'; item.size=len(data)
                archive.addfile(item,io.BytesIO(data))
        run=subprocess.run(['python3',str(script),str(file)],capture_output=True,text=True)
        if case=='ok': assert run.returncode==0, run.stderr
        else: assert run.returncode!=0, case
# A pinned GitHub commit archive uses a different, explicitly checked prefix.
with tempfile.TemporaryDirectory() as td:
    sha = 'a' * 40
    good = pathlib.Path(td) / 'preview.tar.gz'
    with tarfile.open(good,'w:gz') as archive:
        item = tarfile.TarInfo(f'headless-desktop-manager-{sha}/VERSION')
        contents = b'0.3.4\n'
        item.size = len(contents)
        archive.addfile(item, io.BytesIO(contents))
    valid = subprocess.run(['python3',str(script),str(good),f'headless-desktop-manager-{sha}'],capture_output=True,text=True)
    assert valid.returncode == 0, valid.stderr
    bad_prefix = subprocess.run(['python3',str(script),str(good),'headless-desktop-manager-'+('b'*40)],capture_output=True,text=True)
    assert bad_prefix.returncode != 0
print('PASS archive verification')
