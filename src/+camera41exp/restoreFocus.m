function restoreFocus(parent)
%RESTOREFOCUS Return focus once, without timers or position changes.
if ~isempty(parent) && isgraphics(parent) && strcmp(parent.BeingDeleted,'off') && strcmp(parent.Visible,'on')
 figure(parent);
end
end
