function varargout=fileDialog(kind,parent,varargin)
%FILEDIALOG Restore parent focus after synchronous native dialogs.
if ~isgraphics(parent)
 for k=1:nargout,if kind=="input",varargout{k}={};else,varargout{k}=0;end;end
 return
end
started=tic;camera41det.logEvent('dialog.enter',struct('Kind',kind,'Arguments',{varargin}));
cleanup=onCleanup(@()restoreDialogFocus(parent,kind));
try
switch kind
 case "open",[varargout{1:nargout}]=uigetfile(varargin{:});
 case "folder",[varargout{1:nargout}]=uigetdir(varargin{:});
 case "save",[varargout{1:nargout}]=uiputfile(varargin{:});
 case "input",[varargout{1:nargout}]=inputdlg(varargin{:});
 otherwise,error('Camera41:Pre:DialogKind','Unknown dialog kind.');
end
camera41det.logEvent('dialog.return',struct('Kind',kind,'Seconds',toc(started),'IncludesUserSelectionTime',true));
catch err
 camera41det.logEvent('dialog.error',struct('Kind',kind,'Seconds',toc(started),'Report',getReport(err,'extended','hyperlinks','off')));rethrow(err);
end
% A user may close the parent while a native chooser is open.
if ~isgraphics(parent)
 for k=1:nargout,if kind=="input",varargout{k}={};else,varargout{k}=0;end;end
end
end
function restoreDialogFocus(parent,kind)
% Values are captured by onCleanup; no nested exiting workspace is accessed.
focusTimer=tic;camera41det.restoreFocus(parent);
camera41det.logEvent('dialog.focus_restored',struct('Kind',kind,'Seconds',toc(focusTimer)));
end
