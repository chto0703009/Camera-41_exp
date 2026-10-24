function result=prepareDigitizationExposure(inputs,options)
%PREPAREDIGITIZATIONEXPOSURE Preparatory RAW-only exposure bracket, no film fit.
% inputs is a folder containing only FB+F RAWs, or an explicit list of files.
% Does not modify calibration or accept a camera/film production workflow.
arguments
 inputs (:,1) string
 options.OutputRoot (1,1) string
 options.ROI (1,4) double {mustBePositive,mustBeFinite,mustBeInteger}=[1 1 100 100]
 options.AutomaticArea (1,1) logical=true
 options.PassMarginEV (1,1) double {mustBeNonnegative,mustBeFinite}=1/3
 options.FailFraction (1,1) double {mustBeNonnegative,mustBeLessThanOrEqual(options.FailFraction,1)}=1e-4
 options.LinearityTolerance (1,1) double {mustBePositive,mustBeFinite}=0.05
 options.LightSetup (1,1) string
 options.BaseFogNote (1,1) string
end
assert(strlength(strip(options.LightSetup))>0 && strlength(strip(options.BaseFogNote))>0, ...
 'Camera41:Exposure:Setup','Document light setup and physical base+fog identification.');
if isscalar(inputs) && isfolder(inputs)
 d=dir(inputs);d=d(~[d.isdir]);names=string({d.name}).';
 ext=strings(size(names));for k=1:numel(names),[~,~,ext(k)]=fileparts(names(k));end
 supported=ismember(lower(string(ext)),[".cr2",".cr3",".nef",".arw",".dng",".raf",".rw2",".orf",".pef"]);
 inputs=fullfile(inputs,names(supported));
end
assert(~isempty(inputs) && all(isfile(inputs)),'Camera41:Exposure:Inputs','Supply existing FB+F RAW files.');
assert(numel(unique(inputs))==numel(inputs),'Camera41:Exposure:Duplicate','Repeated file path.');
out=options.OutputRoot;assert(~isfolder(out) && ~isfile(out),'Camera41:Exposure:OutputExists','Choose a new result folder.');mkdir(out);
n=numel(inputs);times=zeros(n,1);statuses=strings(n,1);headroom=zeros(n,4);signals=zeros(n,4);above=zeros(n,4);reports=cell(n,1);
sources=struct('Path',{},'SHA256',{});areaChecks=cell(n,1);
for k=1:n
 decodeTimer=tic;camera41exp.logEvent('raw.decode.begin',struct('Index',k,'Count',n,'File',inputs(k)));
 decoded=camera41exp.raw.decode(inputs(k),OutputRoot=fullfile(out,'decode'));
 camera41exp.logEvent('raw.decode.complete',struct('File',inputs(k),'Seconds',toc(decodeTimer)));
 assessmentTimer=tic;
 if k==1,body=string(decoded.CameraIdentity.BodyIdentifierSHA256);iso=decoded.LibRaw.iso;aperture=decoded.LibRaw.aperture;dimensions=[decoded.LibRaw.visible_width decoded.LibRaw.visible_height];end
 assert(string(decoded.CameraIdentity.BodyIdentifierSHA256)==body && decoded.LibRaw.iso==iso && abs(decoded.LibRaw.aperture-aperture)<1e-12 && isequal([decoded.LibRaw.visible_width decoded.LibRaw.visible_height],dimensions), ...
 'Camera41:Exposure:CaptureMismatch','All samples must use the same camera, ISO, aperture and image dimensions.');
 if options.AutomaticArea
  data=load(fullfile(decoded.ResultFolder,decoded.Outputs.LinearSensorFile),'linearMosaic');
  [automaticROI,areaCheck]=camera41exp.automaticArea(data.linearMosaic);areaChecks{k}=areaCheck;
  if k==1,options.ROI=automaticROI;end
  camera41exp.logEvent('roi.automatic',struct('File',inputs(k),'Check',areaCheck));
  assert(~areaCheck.NeedsManualReview,'Camera41:Exposure:FBFStructure','%s: %s Preview the image and adjust the marked area.',inputs(k),join(string(areaCheck.Reasons),' '));
 end
 r=camera41exp.raw.assessValoiCapture(decoded,options.ROI,PassMarginEV=options.PassMarginEV,FailFraction=options.FailFraction);
 camera41exp.logEvent('raw.assessment.complete',struct('File',inputs(k),'Seconds',toc(assessmentTimer),'Status',r.Status,'Channels',r.Channels));
 reports{k}=r;times(k)=r.CameraSettings.ShutterSeconds;statuses(k)=string(r.Status);
 headroom(k,:)=[r.Channels.HeadroomEV];signals(k,:)=[r.Channels.MedianSignalCodes];above(k,:)=[r.ExposureAssessment.Channels.AboveLinearityFraction];
 sources(end+1)=struct('Path',inputs(k),'SHA256',string(decoded.Source.SHA256));
end
[times,order]=sort(times);inputs=inputs(order);statuses=statuses(order);headroom=headroom(order,:);signals=signals(order,:);above=above(order,:);reports=reports(order);sources=sources(order);areaChecks=areaChecks(order);
selection=camera41exp.workflow.selectDigitizationExposure(times,statuses,signals,LinearityTolerance=options.LinearityTolerance);
summary=table(inputs,times,statuses,min(headroom,[],2),'VariableNames',{'RAWFile','ShutterSeconds','Status','MinimumHeadroomEV'});
channels=["R","G1","G2","B"];
for k=1:4
 summary.(char("MedianSignalCodes_"+channels(k)))=signals(:,k);
 summary.(char("HeadroomEV_"+channels(k)))=headroom(:,k);
 summary.(char("AboveLinearityFraction_"+channels(k)))=above(:,k);
end
writetable(summary,fullfile(out,'exposure_summary.csv'));
f=figure('Visible','off','Color','w');cleanup=onCleanup(@() close(f));tiledlayout(2,1);
nexttile;semilogx(times,headroom,'o-');yline(options.PassMarginEV,'--');grid on;xlabel('Time (s)');ylabel('Headroom (EV)');legend(channels,'Location','best');title('Digital camera: film base + fog');
nexttile;semilogx(times,signals./times,'o-');grid on;xlabel('Time (s)');ylabel('Signal / time');legend(channels,'Location','best');title('Proportionality; temporal noise not measured');
exportgraphics(f,fullfile(out,'exposure_summary.png'));
result=struct('Schema','camera41.digitization-exposure-preparation.v1','Status','PREPARATORY_REVIEW', ...
 'LightSetup',options.LightSetup,'BaseFogNote',options.BaseFogNote,'ROI',options.ROI, ...
 'Camera',struct('BodyIdentifierSHA256',body,'ISO',iso,'Aperture',aperture), ...
 'AutomaticArea',options.AutomaticArea,'AreaChecks',{areaChecks},'Sources',sources,'Policy',struct('PassMarginEV',options.PassMarginEV,'FailFraction',options.FailFraction, ...
 'Percentile',99.9,'LinearityTolerance',options.LinearityTolerance), ...
 'Selection',selection,'OutputFiles',struct('Summary','exposure_summary.csv','Figure','exposure_summary.png','Measurements','exposure_measurements.mat'), ...
 'NextStep','Verify candidate with a new capture; measure matched dark pair and illuminated repeats for noise. No calibration settings changed.');
save(fullfile(out,'exposure_measurements.mat'),'reports','summary','selection');
write(fullfile(out,'exposure_preparation.json'),result);
disp(summary(:,1:4));disp(selection);
end
function write(file,value)
fid=fopen(file,'w');assert(fid>=0);cleanup=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(value));
end
