function alertFocus(parent,message,title)
if ~isgraphics(parent),return;end
camera41exposure.logEvent('alert.open',struct('Title',string(title),'Message',string(message)));
uialert(parent,message,title,'CloseFcn',@closed);
 function closed(~,~)
  camera41exposure.restoreFocus(parent);camera41exposure.logEvent('alert.closed',struct('Title',string(title)));
 end
end
