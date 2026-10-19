function run_raw_smoke_test(rawFile)
%RUN_RAW_SMOKE_TEST Real RAW through UI, plots and no-export workflow.
arguments,rawFile (1,1) string,end
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));
a=startCamera41_exposure(Visible="off");cleanup=onCleanup(@() delete(a.Figure));a.SetFiles(rawFile);
a.Controls.AutomaticArea.Value=false;a.Controls.Light.Value='COOL - software release verification only';
a.Controls.Note.Value='Existing FB+F fixture; no new physical qualification';a.Controls.Confirmed.Value=true;
area=[1800 1200 5000 3200];for k=1:4,a.Controls.ROI{k}.Value=area(k);end
out=string(tempname);a.AnalyseTo(out);
assert(~isfolder(out),'Temporary decode folder was not cleaned up.');
assert(height(a.Controls.Summary.Data)==1 && numel(findobj(a.Controls.SignalAxes,'Type','line'))==4);
assert(~isfield(a.Controls,'Save')&&~isfield(a,'SaveTo'));
assert(isfile(a.Controls.LogPath));
disp('REAL_RAW_APP_SMOKE_PASS');
end
