function app=startCamera41_det(options)
%STARTCAMERA41_DET Independent digital-camera exposure preparation.
arguments
 options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])}="on"
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
started=tic;camera41det.logEvent('startup.begin',struct('Visible',options.Visible,'MATLAB',version));
existing=findall(groot,'Type','figure','Tag','Camera41DetApp');
if ~isempty(existing)
 app=getappdata(existing(1),'App');if options.Visible=="on",figure(app.Figure);end;camera41det.logEvent('startup.reused',struct('Seconds',toc(started)));return
end
try
 app=camera41det.app(Visible=options.Visible);
 camera41det.logEvent('startup.complete',struct('Seconds',toc(started)));
catch err
 camera41det.logEvent('startup.error',struct('Report',getReport(err,'extended','hyperlinks','off')));rethrow(err);
end
if nargout==0,assignin('base','camera41DetApp',app);end
end
