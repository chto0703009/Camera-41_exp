function report=setup_python_environment(mode,options)
%SETUP_PYTHON_ENVIRONMENT Maintain this program's own standardized .venv.
arguments
 mode (1,1) string="ensure"
 options.BootstrapPython (1,1) string=""
 options.TimeoutSeconds (1,1) double=900
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
report=camera41exp.runtime.ensurePython(Mode=mode,BootstrapPython=options.BootstrapPython,TimeoutSeconds=options.TimeoutSeconds);
end
