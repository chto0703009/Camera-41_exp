function app=startCamera41_exposure(options)
%STARTCAMERA41_EXPOSURE Independent digital-camera exposure preparation.
arguments
 options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])}="on"
end
root=string(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
existing=findall(groot,'Type','figure','Tag','Camera41ExposureApp');
if ~isempty(existing)
 app=getappdata(existing(1),'App');if options.Visible=="on",figure(app.Figure);end;return
end
app=camera41exposure.app(Visible=options.Visible);
if nargout==0,assignin('base','camera41ExposureApp',app);end
end
