function report=identifyPython()
%IDENTIFYPYTHON Find a base interpreter without creating/changing an environment.
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
managed=dir(fullfile(root,'.python','cpython-3.13.6-*','bin','python3.13'));
candidates=strings(1,0);
for k=1:numel(managed),candidates(end+1)=fullfile(managed(k).folder,managed(k).name);end
if ispc
 [~,paths]=system('where python');
 candidates=reshape(splitlines(strip(string(paths))),1,[]);
else
 % MATLAB launched from Finder may not inherit a terminal's PATH.
 if ismac
  hardware=camera41exp.runtime.nativeArchitecture();
  if hardware.Physical=="arm64",prefixes=["/opt/homebrew/bin","/usr/local/bin"];
  else,prefixes=["/usr/local/bin","/opt/homebrew/bin"];end
  for version="3.13"
   for prefix=prefixes,candidates(end+1)=prefix+"/python"+version;end
   candidates(end+1)="/Library/Frameworks/Python.framework/Versions/"+version+"/bin/python3";
  end
  for prefix=prefixes,candidates(end+1)=prefix+"/python3";end
 end
 [~,paths]=system('command -v python3');
 candidates=[candidates,reshape(splitlines(strip(string(paths))),1,[]),"/usr/bin/python3"];
end
candidates=unique(candidates(candidates~=""),'stable');
report=struct('Status','NOT_FOUND','Executable','','PythonVersion','','Architecture','');
fprintf('Looking for Python 3.13.6 (no environment changes).\n');
hardware=camera41exp.runtime.nativeArchitecture();best=-1;
for candidate=candidates
 if ~isfile(candidate),continue;end
 try
  [status,out]=camera41exp.runtime.invoke(candidate,["-I","-c", ...
   "import sys,json,platform; print(json.dumps(dict(Executable=sys.executable,PythonVersion=platform.python_version(),Architecture=platform.machine(),Compatible=sys.version_info[:3]==(3,13,6),Base=sys.prefix==sys.base_prefix)))"],15);
  if status~=0,fprintf('Unavailable: %s\n',candidate);continue;end
  info=jsondecode(out);
  fprintf('Python %s / %s: %s\n',info.PythonVersion,info.Architecture,candidate);
  score=double(string(info.Architecture)==hardware.Physical);
  if info.Compatible && info.Base && score>best
   best=score;
   report.Status='FOUND';report.Executable=char(candidate);
   report.PythonVersion=info.PythonVersion;report.Architecture=info.Architecture;
  end
 catch
  fprintf('Could not inspect: %s\n',candidate);
 end
end
if string(report.Status)=="FOUND",fprintf('Selected: %s\n',report.Executable);
else,fprintf('No compatible base interpreter found. Prepare/rebuild can download private Python 3.13.6 on macOS; identify makes no changes.\n');end
end
