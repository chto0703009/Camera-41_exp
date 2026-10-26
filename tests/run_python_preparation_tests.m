function run_python_preparation_tests(options)
%RUN_PYTHON_PREPARATION_TESTS Optional real download in a disposable installation.
arguments
 options.Download (1,1) logical=false
end
root=string(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(root,'src'));
report=camera41exp.runtime.ensureRawProbe();
assert(isfield(report,'LibRawVersion'));
if ~options.Download
 disp('RAW_PREPARATION_PASS; Python download test skipped (use Download=true).');return
end
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@() rmdir(folder,'s'));
python=camera41exp.runtime.preparePython(folder,600);
copyfile(fullfile(root,'requirements.txt'),fullfile(folder,'requirements.txt'));
copyfile(fullfile(root,'requirements-tools.txt'),fullfile(folder,'requirements-tools.txt'));
[status,output]=camera41exp.runtime.invoke(python,["-I",fullfile(root,'tools','manage_python_environment.py'),"sync","--root",folder],900);
assert(status==0,'Camera41:Test:PythonPreparation','%s',output);
if ispc,local=fullfile(folder,'.venv','Scripts','python.exe');else,local=fullfile(folder,'.venv','bin','python');end
[status,output]=camera41exp.runtime.invoke(local,["-I",fullfile(root,'tools','manage_python_environment.py'),"check","--root",folder],180);
assert(status==0,'Camera41:Test:PythonHealth','%s',output);
report=jsondecode(output);assert(string(report.PythonVersion)=="3.13.6" && report.Isolated);
disp('PRIVATE_PYTHON_PREPARATION_AND_HEALTH_PASS');
end
