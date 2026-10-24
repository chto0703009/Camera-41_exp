"""Build a clean, checksummed release from tracked files using Python stdlib."""
from pathlib import Path
import hashlib
import json
import shutil
import stat
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],text=True).strip()
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    if git('status','--porcelain','--untracked-files=no'):
        raise SystemExit('Commit tracked changes before building a release.')
    version=(ROOT/'VERSION').read_text().strip()
    if version!='0.1.2':raise SystemExit('Review release metadata for this version first.')
    commit=git('rev-parse','HEAD');prefix=f'Camera-41_exp-v{version}'
    files=git('ls-files','-s').splitlines();entries=[]
    for line in files:
        mode=line.split(None,1)[0]
        # git ls-files -s: mode, object, stage<TAB>path
        name=line.split('\t',1)[1]
        if name.split('/')[0] in {'logs','tmp','.git','.venv','dist'}:raise SystemExit('Private/build file tracked: '+name)
        if Path(name).suffix.lower() in {'.cr2','.cr3','.dng','.nef','.arw','.raf','.rw2','.orf','.pef'}:raise SystemExit('RAW file tracked: '+name)
        if mode=='120000':raise SystemExit('Review symbolic link before release: '+name)
        data=(ROOT/name).read_bytes();entries.append((name,data,0o755 if mode=='100755' else 0o644))
    required={'VERSION','start.m','startCamera41_exp.m','LICENSE','LICENSE_NOTICE.md','INSTALL.md',
              'output/pdf/Camera41_exp_Handbook_SV.pdf','output/pdf/Camera41_exp_Handbook_EN.pdf'}
    if not required.issubset({e[0] for e in entries}):raise SystemExit('Required release file missing.')
    manifest={'Schema':'camera41.exposure-release.v1','Version':version,'SourceCommit':commit,
              'Platform':'macOS / MATLAB','VerifiedPlatform':'Apple Silicon / MATLAB R2025b',
              'PhysicalIntelVerified':False,'PREorNEGRequired':False,
              'Files':{name:{'Bytes':len(data),'SHA256':sha(data)} for name,data,_ in entries}}
    dist=ROOT/'dist'/f'v{version}';dist.mkdir(parents=True,exist_ok=True)
    archive=dist/f'{prefix}-macos.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data,mode in entries+[('RELEASE_MANIFEST.json',(json.dumps(manifest,indent=2)+'\n').encode(),0o644)]:
            info=zipfile.ZipInfo(prefix+'/'+name,date_time=(2026,10,23,0,0,0));info.create_system=3
            info.external_attr=(stat.S_IFREG|mode)<<16;info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,data)
    assets=[archive]
    for name in ['Camera41_exp_Handbook_SV.pdf','Camera41_exp_Handbook_EN.pdf','Camera41_exp_Sammanfattning_SV.pdf','Camera41_exp_Summary_EN.pdf']:
        file=ROOT/'output/pdf'/name;target=dist/file.name;shutil.copy2(file,target);assets.append(target)
    sums=dist/'SHA256SUMS.txt';sums.write_text(''.join(f'{sha(f.read_bytes())}  {f.name}\n' for f in assets))
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        parsed=json.loads(z.read(prefix+'/RELEASE_MANIFEST.json'))
        for name,entry in parsed['Files'].items():assert sha(z.read(prefix+'/'+name))==entry['SHA256']
    print(json.dumps({'Archive':str(archive),'SourceCommit':commit,'Files':len(entries),'Bytes':archive.stat().st_size,'Checksums':str(sums)},indent=2))
if __name__=='__main__':main()
