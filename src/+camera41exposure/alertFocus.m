function alertFocus(parent,message,title)
if ~isgraphics(parent),return;end
uialert(parent,message,title,'CloseFcn',@(~,~)camera41exposure.restoreFocus(parent));
end
