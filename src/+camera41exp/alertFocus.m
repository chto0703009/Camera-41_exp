function alertFocus(parent,message,title)
if ~isgraphics(parent),return;end
camera41exp.logEvent('alert.open',struct('Title',string(title),'Message',string(message)));
uialert(parent,message,title,'CloseFcn',@closed);
 function closed(~,~)
  camera41exp.restoreFocus(parent);camera41exp.logEvent('alert.closed',struct('Title',string(title)));
 end
end
