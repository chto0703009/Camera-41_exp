function app=startCamera41_exp(options)
%STARTCAMERA41_EXP Independent digital-camera exposure preparation.
arguments
 options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])}="on"
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
started=tic;camera41exp.logEvent('startup.begin',struct('Visible',options.Visible,'MATLAB',version));
existing=findall(groot,'Type','figure','Tag','Camera41ExpApp');
if ~isempty(existing)
 app=getappdata(existing(1),'App');if options.Visible=="on",figure(app.Figure);end;camera41exp.logEvent('startup.reused',struct('Seconds',toc(started)));return
end
try
 camera41exp.runtime.ensurePython();
 camera41exp.runtime.ensureRawProbe();
 app=camera41exp.app(Visible=options.Visible);
 camera41exp.logEvent('startup.complete',struct('Seconds',toc(started)));
catch err
 camera41exp.logEvent('startup.error',struct('Report',getReport(err,'extended','hyperlinks','off')));rethrow(err);
end
if nargout==0,assignin('base','camera41ExpApp',app);end
end
