function alertFocus(parent,message,title)
if ~isgraphics(parent),return;end
camera41det.logEvent('alert.open',struct('Title',string(title),'Message',string(message)));
uialert(parent,message,title,'CloseFcn',@closed);
 function closed(~,~)
  camera41det.restoreFocus(parent);camera41det.logEvent('alert.closed',struct('Title',string(title)));
 end
end
