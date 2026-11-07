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
print('PASS archive verification')
