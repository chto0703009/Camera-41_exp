function run_exposure_report_tests
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));
r=struct('ROI',[1 1 100 100],'Policy',struct('PassMarginEV',1/3,'FailFraction',1e-4));
t=table("test.CR2",1,"FAIL",-.2,'VariableNames',{'RAWFile','ShutterSeconds','Status','MinimumHeadroomEV'});
for ch=["R","G1","G2","B"],t.(char("MedianSignalCodes_"+ch))=16000;t.(char("HeadroomEV_"+ch))=-.2;t.(char("AboveLinearityFraction_"+ch))=.1;end
[v,lines]=camera41exp.explainResults(t,r);assert(contains(v.Explanation,'shorter'));assert(any(contains(lines,'10.0000 %')));assert(any(contains(lines,'One image')));
a=startCamera41_exp(Visible="off");assert(~isfield(a.Controls,'Save')&&~isfield(a,'SaveTo'));delete(a.Figure);disp('FAIL_REPORT_PASS');
end
