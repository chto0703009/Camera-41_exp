function run_dialog_cleanup_tests
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));
f=uifigure('Visible','off');cleanup=onCleanup(@() delete(f));
lastwarn('');caught=false;
try,camera41exposure.fileDialog("test-invalid-kind",f);catch err,caught=strcmp(err.identifier,'Camera41:Pre:DialogKind');end
assert(caught);[message,~]=lastwarn;assert(isempty(message),'Dialog cleanup emitted a warning.');
file=camera41exposure.logEvent('test.dialog_cleanup');lines=readlines(file);lines=lines(strlength(lines)>0);
record=jsondecode(lines(end-1));assert(string(record.Event)=="dialog.focus_restored");
disp('DIALOG_CLEANUP_PASS');
end
