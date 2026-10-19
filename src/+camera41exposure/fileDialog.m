function varargout=fileDialog(kind,parent,varargin)
%FILEDIALOG Restore parent focus after synchronous native dialogs.
if ~isgraphics(parent)
 for k=1:nargout,if kind=="input",varargout{k}={};else,varargout{k}=0;end;end
 return
end
cleanup=onCleanup(@()camera41exposure.restoreFocus(parent));
switch kind
 case "open",[varargout{1:nargout}]=uigetfile(varargin{:});
 case "folder",[varargout{1:nargout}]=uigetdir(varargin{:});
 case "save",[varargout{1:nargout}]=uiputfile(varargin{:});
 case "input",[varargout{1:nargout}]=inputdlg(varargin{:});
 otherwise,error('Camera41:Pre:DialogKind','Unknown dialog kind.');
end
% A user may close the parent while a native chooser is open.
if ~isgraphics(parent)
 for k=1:nargout,if kind=="input",varargout{k}={};else,varargout{k}=0;end;end
end
end
