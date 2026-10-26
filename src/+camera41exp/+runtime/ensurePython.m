function report=ensurePython(options)
%ENSUREPYTHON Verify runtime and offer safe preparation on this computer.
arguments
 options.Mode (1,1) string {mustBeMember(options.Mode,["ensure","check","sync","rebuild","tools","identify"])}="ensure"
 options.BootstrapPython (1,1) string=""
 options.TimeoutSeconds (1,1) double=900
end
% Normal startup checks first; repair requires an explicit desktop choice.
% Maintenance/check modes never open dialogs or silently change packages.
if options.Mode=="ensure"
 try
  report=camera41exp.runtime.ensurePython(Mode="check",BootstrapPython=options.BootstrapPython,TimeoutSeconds=options.TimeoutSeconds);
  return
 catch failure
  message=sprintf(['The Python environment needs to be prepared for this computer.\n\n' ...
   'A moved, missing or incompatible environment can be rebuilt. Missing Python 3.13.6 is downloaded privately on macOS; system Python is unchanged. Internet access may be required. ' ...
   'The existing environment is backed up and restored if installation fails.\n\nReason: %s'],failure.message);
  choice="";
  if usejava('desktop')
   choice=string(questdlg(message,'Prepare for this computer','Prepare','Cancel','Prepare'));
  end
  if choice~="Prepare"
   throwAsCaller(MException('Camera41:Python:PreparationRequired', ...
    'Startup cancelled. The Python environment needs preparation. Run camera41exp.runtime.ensurePython(Mode="rebuild") to install without a dialog.\n%s',failure.message));
  end
  fprintf('Preparing the Python environment for this computer. This may take several minutes.\n');drawnow;
  report=camera41exp.runtime.ensurePython(Mode="rebuild",BootstrapPython=options.BootstrapPython,TimeoutSeconds=options.TimeoutSeconds);
  return
 end
end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
if ispc,python=fullfile(root,'.venv','Scripts','python.exe');else,python=fullfile(root,'.venv','bin','python');end
mode=options.Mode;profile="runtime";if mode=="tools",mode="sync";profile="tools";end
bootstrap=options.BootstrapPython;
if bootstrap=="" && isfile(python) && mode~="rebuild",bootstrap=python;end
if bootstrap=="" || mode=="identify"
 discovery=camera41exp.runtime.identifyPython();
 if mode=="identify",report=discovery;return;end
 bootstrap=string(discovery.Executable);
end
if bootstrap=="" && any(mode==["rebuild","sync"])
 bootstrap=camera41exp.runtime.preparePython(root,options.TimeoutSeconds);
end
assert(bootstrap~="",'Camera41:Python:Bootstrap', ...
 'Python 3.13.6 is not ready. Run setup_python_environment("rebuild") to prepare a private interpreter, or supply BootstrapPython explicitly.');
fprintf('Camera-41 Python interpreter: %s\n',bootstrap);
file=string(tempname)+".json";cleanup=onCleanup(@() remove(file));
if mode~="check" && ~isfile(python),fprintf('Creating the isolated Camera-41 Python environment and installing dependencies. The first installation requires internet access.\n');end
args=["-I",fullfile(root,'tools','manage_python_environment.py'),mode,"--root",root,"--profile",profile,"--output",file];
[status,output]=camera41exp.runtime.invoke(bootstrap,args,options.TimeoutSeconds);
assert(status==0 && isfile(file),'Camera41:Python:Environment', ...
 'The Python environment could not be verified.\n%s\nCheck: setup_python_environment("check")\nSynchronize: setup_python_environment("sync")\nRebuild: setup_python_environment("rebuild")',output);
report=jsondecode(fileread(file));
if mode=="check" && isfield(report,'Architecture') && string(report.Architecture)=="x86_64"
 hardware=camera41exp.runtime.nativeArchitecture();
 if hardware.Physical=="arm64"
  discovery=camera41exp.runtime.identifyPython();
  assert(string(discovery.Architecture)~="arm64",'Camera41:Python:NativeAvailable', ...
   'An ARM Python is available. Rebuild this local environment to use the native ARM version.');
 end
end
end
function remove(file),if isfile(file),delete(file);end,end
