function run_exposure_tests
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));
% Preparatory exposure: every replicate must pass; bracket and linearity matter.
times=[1;2;4;5];signal=times.*[100 80 70 60];
a=camera41exposure.workflow.selectDigitizationExposure(times,["PASS";"PASS";"PASS";"REVIEW"],signal);
assert(a.CandidateShutterSeconds==4 && string(a.Status)=="HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY" && string(a.Linearity.Status)=="PROPORTIONALITY_CHECK_PASS" && ~a.HasMeasuredNoise);
b=camera41exposure.workflow.selectDigitizationExposure([1;2;4],["PASS";"PASS";"PASS"],signal(1:3,:));
assert(string(b.Status)=="PROVISIONAL_ADD_HIGHER_EXPOSURE");
b=camera41exposure.workflow.selectDigitizationExposure([1;2;4;4],["PASS";"PASS";"PASS";"FAIL"],signal);
assert(b.CandidateShutterSeconds==2 && string(b.Status)=="PROVISIONAL_REFINE_BRACKET");
signal(3,:)=signal(3,:)*0.7;b=camera41exposure.workflow.selectDigitizationExposure(times,["PASS";"PASS";"PASS";"REVIEW"],signal);
assert(string(b.Status)=="REVIEW_LINEAR_RESPONSE_BEFORE_USING_CANDIDATE");
b=camera41exposure.workflow.selectDigitizationExposure([1;2],["FAIL";"REVIEW"],ones(2,4));assert(isempty(b.CandidateShutterSeconds));

% Native dialogs return char for one filename and a cell array for multiple.
t=string(tempname);mkdir(t);fileCleanup=onCleanup(@() rmdir(t,'s'));
f1=fullfile(t,'single raw.CR2');f2=fullfile(t,'second.CR2');writelines('test',f1);writelines('test',f2);
assert(isequal(camera41exposure.selectedPaths(t,'single raw.CR2'),f1));
assert(isequal(camera41exposure.selectedPaths(t,{'single raw.CR2','second.CR2'}),[f1;f2]));
assert(isempty(camera41exposure.selectedPaths(t,0)));
a=startCamera41_exposure(Visible="off");cleanup=onCleanup(@() delete(a.Figure));
a.SetFiles(char(f1));assert(size(a.Controls.Files.Data,1)==1);
a.SetFiles(camera41exposure.selectedPaths(t,{'single raw.CR2','second.CR2'}));assert(size(a.Controls.Files.Data,1)==2);
assert(isvalid(a.Figure));b=startCamera41_exposure(Visible="off");assert(a.Figure==b.Figure);
% No PRE/NEG namespace or project is required by this application.
assert(isempty(strfind(fileread(fullfile(root,'src','+camera41exposure','app.m')),'camera41.pre.')));
disp('EXPOSURE_TESTS_PASS');
end
