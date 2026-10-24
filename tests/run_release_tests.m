function run_release_tests(rawFile)
%RUN_RELEASE_TESTS Release checks; optional real RAW is never shipped.
arguments,rawFile (1,1) string="",end
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'),fullfile(root,'tests'));
assert(strtrim(string(fileread(fullfile(root,'VERSION'))))=="0.1.2");
run_exposure_tests;run_exposure_report_tests;run_automatic_area_tests;run_dialog_cleanup_tests;
if rawFile~="",run_raw_smoke_test(rawFile);end
fprintf('MATLAB: %s\n',version);
fprintf('drawrectangle: %s\n',which('drawrectangle'));
fprintf('imshow: %s\n',which('imshow'));
fprintf('prctile: %s\n',which('prctile'));
disp('RELEASE_TESTS_PASS');
end
