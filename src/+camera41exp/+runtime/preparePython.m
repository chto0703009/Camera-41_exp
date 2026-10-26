function python=preparePython(root,timeout)
%PREPAREPYTHON Install a private pinned interpreter without changing system Python.
assert(ismac,'Camera41:Python:Platform','Automatic Python download currently supports macOS. Supply BootstrapPython on other systems.');
hardware=camera41exp.runtime.nativeArchitecture();
if hardware.Physical=="arm64"
 url="https://files.pythonhosted.org/packages/b2/26/bd6438cf6d84a6b0b608bcbe9f353d8e424f8fe3b1b73a768984a76bf80b/uv-0.9.5-py3-none-macosx_11_0_arm64.whl";
 expected="8603bb902e578463c50c3ddd4ee376ba4172ccdf4979787f8948747d1bb0e18b";arch="aarch64";
else
 url="https://files.pythonhosted.org/packages/4e/6c/3508d67f80aac0ddb5806680a6735ff6cb5a14e9b697e5ae145b01050880/uv-0.9.5-py3-none-macosx_10_12_x86_64.whl";
 expected="922cd784cce36bbdc7754b590d28c276698c85791c18cd4c6a7e917db4480440";arch="x86_64";
end
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@() rmdir(folder,'s'));
archive=fullfile(folder,'uv.zip');
fprintf('Downloading verified Python preparation tool (uv 0.9.5 / %s)...\n',hardware.Physical);drawnow;
websave(archive,url,weboptions('Timeout',min(timeout,120)));
handle=fopen(archive,'rb');assert(handle>=0,'Cannot read downloaded preparation tool.');closeFile=onCleanup(@() fclose(handle));bytes=fread(handle,Inf,'*uint8');clear closeFile;
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
actual=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
assert(actual==expected,'Camera41:Python:DownloadHash','Python preparation tool checksum mismatch. No downloaded code was run.');
unzip(archive,folder);uv=fullfile(folder,'uv-0.9.5.data','scripts','uv');
[status,out]=camera41exp.runtime.invoke('/bin/chmod',["u+x",uv],30);assert(status==0,'Camera41:Python:Permissions','%s',out);
install=fullfile(root,'.python');target="cpython-3.13.6-macos-"+arch+"-none";
fprintf('Preparing private Python 3.13.6 (%s). System installations are unchanged.\n',hardware.Physical);drawnow;
[status,out]=camera41exp.runtime.invoke(uv,["--no-config","--no-cache","--native-tls","python","install","--install-dir",install,"--no-bin","--no-registry",target],timeout);
assert(status==0,'Camera41:Python:Download','Private Python preparation failed. Check internet access to PyPI and GitHub, then retry.\n%s',out);
python=fullfile(install,target,'bin','python3.13');
[status,out]=camera41exp.runtime.invoke(python,["-I","-c","import sys,platform; assert sys.version_info[:3]==(3,13,6); print(platform.machine())"],30);
assert(status==0 && strip(out)==hardware.Physical,'Camera41:Python:DownloadedRuntime','Downloaded Python failed its version/architecture check.\n%s',out);
end
