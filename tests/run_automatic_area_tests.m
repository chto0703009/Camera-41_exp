function run_automatic_area_tests
root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'src'));
m=ones(600,900,'single')*.3;m(:,1:60)=0;m(1:60,:)=0;
[roi,c]=camera41det.automaticArea(m);assert(~c.NeedsManualReview && roi(1)>60 && roi(2)>60);
assert(roi(1)+roi(3)-1<=900 && roi(2)+roi(4)-1<=600);
m(220:380,350:550)=.02;[~,c]=camera41det.automaticArea(m);assert(c.NeedsManualReview);
[~,c]=camera41det.automaticArea(ones(600,900,'single')*1.1);assert(~c.NeedsManualReview,'Uniform overexposure must be reported by exposure checks, not as image structure.');
r=camera41det.clampArea([101 1 8639 5699],[8736 5856]);assert(r(1)+r(3)-1<=8736);
a=startCamera41_det(Visible="off");assert(a.Controls.AutomaticArea.Value);delete(a.Figure);
disp('AUTOMATIC_AREA_PASS');
end
