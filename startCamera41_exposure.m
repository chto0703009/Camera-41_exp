function app=startCamera41_exposure(options)
%STARTCAMERA41_EXPOSURE Independent digital-camera exposure preparation.
arguments
 options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])}="on"
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
started=tic;camera41exposure.logEvent('startup.begin',struct('Visible',options.Visible,'MATLAB',version));
existing=findall(groot,'Type','figure','Tag','Camera41ExposureApp');
if ~isempty(existing)
 app=getappdata(existing(1),'App');if options.Visible=="on",figure(app.Figure);end;camera41exposure.logEvent('startup.reused',struct('Seconds',toc(started)));return
end
try
 app=camera41exposure.app(Visible=options.Visible);
 camera41exposure.logEvent('startup.complete',struct('Seconds',toc(started)));
catch err
 camera41exposure.logEvent('startup.error',struct('Report',getReport(err,'extended','hyperlinks','off')));rethrow(err);
end
if nargout==0,assignin('base','camera41ExposureApp',app);end
end
