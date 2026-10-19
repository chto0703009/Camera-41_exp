function app=app(options)
%APP Exposure bracket without PRE projects, film profiles or Python setup.
arguments
 options.Visible (1,1) string="on"
end
lastRAWFolder=string(getpref('Camera41Exposure','LastRAWFolder',char(java.lang.System.getProperty('user.home'))));
folderTimer=tic;camera41exposure.logEvent('folder.check.begin',struct('Folder',lastRAWFolder));
if ~isfolder(lastRAWFolder),lastRAWFolder=string(java.lang.System.getProperty('user.home'));end
camera41exposure.logEvent('folder.check.complete',struct('Folder',lastRAWFolder,'Seconds',toc(folderTimer)));
files=strings(0,1);selected=1;previewFile="";rectangle=[];running=false;result=[];analysisTable=[];visibleSize=[];manualRequired=false;manualReady=false;manualReason="";
f=uifigure('Name','Camera-41 Exposure – digital camera setup','Tag','Camera41ExposureApp','Visible',options.Visible,'Position',[80 80 1250 820]);
f.CloseRequestFcn=@closeApp;
logPath=camera41exposure.logEvent('window.created',struct());
menu=uimenu(f,'Text','Log');uimenu(menu,'Text','Open complete log','MenuSelectedFcn',@(~,~)edit(logPath));
g=uigridlayout(f,[8 1]);g.RowHeight={42,38,60,40,34,'1x',150,36};
uilabel(g,'Text',{'Choose the digital-camera shutter time at a fixed, selected aperture using blank film base + fog RAWs.', ...
 'Compare signal and clipping margin, then save JSON for PRE. PRE includes it in the film characterisation exported to NEG.'}, ...
 'WordWrap','on','Tag','Camera41ExposurePurpose');
bar=uigridlayout(g,[1 4]);bar.Padding=[0 0 0 0];
add=uibutton(bar,'Text','Add FB+F RAW files …','ButtonPushedFcn',@addFiles);
remove=uibutton(bar,'Text','Remove selected','ButtonPushedFcn',@removeFile);
preview=uibutton(bar,'Text','Preview selected RAW','ButtonPushedFcn',@showPreview);
draw=uibutton(bar,'Text','Adjust marked area','ButtonPushedFcn',@drawArea);
setup=uigridlayout(g,[2 2]);setup.Padding=[0 0 0 0];setup.ColumnWidth={240,'1x'};
uilabel(setup,'Text','Light source / mode / setup');light=uieditfield(setup,'text','ValueChangedFcn',@changed);
uilabel(setup,'Text','Physical film base + fog identification');note=uieditfield(setup,'text','ValueChangedFcn',@changed);
r=uigridlayout(g,[1 10]);r.Padding=[0 0 0 0];r.ColumnWidth={25,90,25,90,50,90,50,90,160,'1x'};
coords=cell(1,4);labels={'X','Y','Width','Height'};
for k=1:4,uilabel(r,'Text',labels{k});coords{k}=uieditfield(r,'numeric','Limits',[1 Inf],'RoundFractionalValues','on','Value',1,'ValueChangedFcn',@roiEdited);end
coords{3}.Value=100;coords{4}.Value=100;
automatic=uicheckbox(r,'Text','Automatic area','Value',true,'ValueChangedFcn',@areaModeChanged);
confirm=uicheckbox(r,'Text','Same FB+F sample in all RAWs','ValueChangedFcn',@changed);
uilabel(g,'Text','The app selects an area away from the edges. Manual adjustment is requested only for a visibly uneven or suspect FB+F image.');
body=uigridlayout(g,[1 2]);body.ColumnWidth={'1x','1x'};
left=uigridlayout(body,[2 1]);left.RowHeight={'1x','1x'};
list=uitable(left,'ColumnName',{'FB+F RAW file'},'ColumnWidth',{'auto'},'CellSelectionCallback',@select);
summary=uitable(left);
views=uitabgroup(body);previewTab=uitab(views,'Title','RAW preview');comparisonTab=uitab(views,'Title','Exposure comparison');
pg=uigridlayout(previewTab,[1 1]);ax=uiaxes(pg);axis(ax,'off');title(ax,'Click Preview selected RAW to view the image and choose a clean film-base area');
cg=uigridlayout(comparisonTab,[2 1]);signalAxes=uiaxes(cg);marginAxes=uiaxes(cg);

status=uitextarea(g,'Editable','off','Value',{'Add an exposure bracket, preview a RAW and draw the measurement area.','Analysis uses unchanged RAW sensor measurements. No PRE project is opened.','The proposed time must be verified with a new capture. Temporal noise is not measured by this test.'});
foot=uigridlayout(g,[1 5]);foot.ColumnWidth={170,'1x',190,150,80};foot.Padding=[0 0 0 0];
run=uibutton(foot,'Text','Analyse RAW images','ButtonPushedFcn',@(~,~) analyse());
chosen=uidropdown(foot,'Items',{'Analyse first'},'ItemsData',{''},'Enable','off');
saveButton=uibutton(foot,'Text','Save selected time as JSON …','Enable','off','ButtonPushedFcn',@saveResult);
reportButton=uibutton(foot,'Text','Save report …','Enable','off','ButtonPushedFcn',@saveReport);

uibutton(foot,'Text','Close','ButtonPushedFcn',@closeApp);
app=struct('Figure',f,'Controls',struct('Add',add,'Remove',remove,'Preview',preview,'DrawROI',draw,'Analyse',run,'Light',light,'Note',note,'Confirmed',confirm,'ROI',{coords},'AutomaticArea',automatic,'Files',list,'Summary',summary,'Status',status,'LogPath',logPath,'ExposureTime',chosen,'Save',saveButton,'SaveReport',reportButton,'SignalAxes',signalAxes,'MarginAxes',marginAxes),'SetFiles',@setFiles,'AnalyseTo',@analyse,'SaveTo',@saveTo,'GetLastRAWFolder',@() lastRAWFolder);
setappdata(f,'App',app);areaMode();
 function areaModeChanged(~,~),areaMode();changed();end
 function roiEdited(~,~)
  manualReady=true;changed();
 end
 function areaMode(~,~)
  for j=1:4,coords{j}.Editable=~automatic.Value;end
 end
 function changed(~,~)
  camera41exposure.logEvent('settings.changed',struct('Light',light.Value,'Sample',note.Value,'ROI',cellfun(@(c)c.Value,coords),'Confirmed',confirm.Value));
  result=[];analysisTable=[];chosen.Enable='off';saveButton.Enable='off';reportButton.Enable='off';cla(signalAxes);cla(marginAxes);summary.Data={};status.Value={'Settings changed. Analyse again to obtain a result for these settings.'};
 end
 function setFiles(paths)
  updateTimer=tic;camera41exposure.logEvent('files.update.begin',struct('Count',numel(string(paths))));
  assert(~running,'An operation is running.');paths=string(paths);paths=paths(:);missing=paths(~isfile(paths));assert(isempty(missing),'RAW file missing: %s',join(missing,newline));
  files=unique(paths,'stable');selected=1;manualRequired=false;manualReady=false;automatic.Value=true;areaMode();previewFile="";cla(ax);list.Data=cellstr(files);changed();camera41exposure.logEvent('files.update.complete',struct('Count',numel(files),'Seconds',toc(updateTimer)));
 end
 function addFiles(~,~)
  clickTimer=tic;camera41exposure.logEvent('raw_picker.click',struct('Folder',lastRAWFolder));
  drawnow;camera41exposure.logEvent('raw_picker.before_dialog',struct('SecondsSinceClick',toc(clickTimer)));
  [names,folder]=camera41exposure.fileDialog("open",f,{'*.CR2;*.cr2;*.CR3;*.cr3;*.NEF;*.nef;*.ARW;*.arw;*.DNG;*.dng;*.RAF;*.raf;*.RW2;*.rw2;*.ORF;*.orf;*.PEF;*.pef','RAW files'},'Select film-base exposure bracket',char(lastRAWFolder+filesep),'MultiSelect','on');
  if isequal(names,0),camera41exposure.logEvent('raw_picker.cancel',struct('Seconds',toc(clickTimer)));return;end
  camera41exposure.logEvent('raw_picker.selected',struct('Folder',string(folder),'Names',{cellstr(string(names))},'Seconds',toc(clickTimer)));
  lastRAWFolder=string(folder);setpref('Camera41Exposure','LastRAWFolder',char(lastRAWFolder));
  try,setFiles([files;camera41exposure.selectedPaths(folder,names)]);catch err,report(err);end
 end
 function select(~,event),if ~isempty(event.Indices),selected=event.Indices(1,1);end,end
 function removeFile(~,~)
  if isempty(files),return;end;files(selected)=[];setFiles(files);
 end
 function begin()
  camera41exposure.logEvent('operation.busy',struct());
  assert(~running,'An operation is running.');running=true;
  for c=[add remove preview draw run chosen saveButton reportButton],c.Enable='off';end
  light.Enable='off';note.Enable='off';confirm.Enable='off';automatic.Enable='off';for j=1:4,coords{j}.Enable='off';end;drawnow;
 end
 function finish()
  camera41exposure.logEvent('operation.finished',struct());
  running=false;if ~isvalid(f),return;end
  for c=[add remove preview draw run],c.Enable='on';end
  light.Enable='on';note.Enable='on';confirm.Enable='on';automatic.Enable='on';areaMode();for j=1:4,coords{j}.Enable='on';end
  if ~isempty(result),reportButton.Enable='on';end
  if ~isempty(result) && any(string(analysisTable.Status)=="PASS"),chosen.Enable='on';saveButton.Enable='on';end
 end
 function showPreview(~,~)
  previewTimer=tic;camera41exposure.logEvent('preview.begin',struct('SelectedRow',selected));
  temp="";
  try
   assert(~isempty(files),'Add RAW files first.');begin();done=onCleanup(@finish);
   status.Value={'Decoding selected RAW …'};drawnow;temp=string(tempname);mkdir(temp);cleanup=onCleanup(@() removeTemp(temp));
   d=camera41exposure.raw.decode(files(selected),OutputRoot=temp);
   data=load(fullfile(d.ResultFolder,d.Outputs.LinearSensorFile),'linearMosaic');m=data.linearMosaic;visibleSize=[size(m,2) size(m,1)];
   if automatic.Value || manualRequired
    [area,areaCheck]=camera41exposure.automaticArea(m);for j=1:4,coords{j}.Value=area(j);end
   end
   h=2*floor(size(m,1)/2);w=2*floor(size(m,2)/2);
   v=(m(1:2:h,1:2:w)+m(2:2:h,1:2:w)+m(1:2:h,2:2:w)+m(2:2:h,2:2:w))/4;
   imagesc(ax,[1 w],[1 h],sqrt(max(0,min(1,v(1:4:end,1:4:end)))));colormap(ax,gray);axis(ax,'image');ax.YDir='reverse';
   views.SelectedTab=previewTab;title(ax,'Display only; measurement area uses native sensor pixels');previewFile=files(selected);rectangle=[];camera41exposure.logEvent('preview.complete',struct('File',previewFile,'Seconds',toc(previewTimer)));
   rectangle=drawrectangle(ax,'Position',camera41exposure.clampArea(cellfun(@(c)c.Value,coords),visibleSize),'Color','y');addlistener(rectangle,'ROIMoved',@areaChanged);
   if manualRequired
    automatic.Value=false;areaMode();status.Value=cellstr(["VARNING: bilden avviker från förväntad tom FB+F. Det föreslagna området är markerat i gult. Justera rutan till ren filmbas + slöja.";manualReason]);
   else,status.Value={'Automatiskt mätområde är markerat i gult och undviker bildkanterna.'};end
  catch err,report(err);end
 end
 function drawArea(~,~)
  camera41exposure.logEvent('roi.draw',struct());
  try
   assert(previewFile~="",'Preview a RAW first.');
   if ~isempty(rectangle)&&isvalid(rectangle),delete(rectangle);end
   automatic.Value=false;areaMode();rectangle=drawrectangle(ax,'Position',camera41exposure.clampArea(cellfun(@(c)c.Value,coords),visibleSize),'Color','y');
   addlistener(rectangle,'ROIMoved',@areaChanged);areaChanged();
  catch err,report(err);end
 end
 function areaChanged(~,~)
  p=camera41exposure.clampArea(rectangle.Position,visibleSize);rectangle.Position=p;automatic.Value=false;manualReady=true;areaMode();for j=1:4,coords{j}.Value=p(j);end;changed();camera41exposure.logEvent('roi.changed',struct('ROI',p));
 end
 function analyse(out)
  analysisTimer=tic;camera41exposure.logEvent('analysis.begin',struct('Files',{cellstr(files)},'ROI',cellfun(@(c)c.Value,coords)));
  if nargin==0,out=string(tempname);end
  try
   assert(~isempty(files),'Add RAW files first.');assert(confirm.Value,'Confirm that every RAW shows the same film-base sample.');
   assert(strlength(strip(string(light.Value)))>0 && strlength(strip(string(note.Value)))>0,'Describe the light and film-base sample.');
   assert(~manualRequired || manualReady,'Justera den gula markeringen innan analysen fortsätter.');
   roi=cellfun(@(c)c.Value,coords);assert(all(roi(3:4)>=20),'Use a measurement area at least 20 x 20 pixels.');
   begin();done=onCleanup(@finish);status.Value={'Analysing RAW exposures … Comparing signal and clipping margin.'};drawnow;
   assert(~isfolder(out)&&~isfile(out),'Choose a new temporary analysis folder.');
   result=[];analysisTable=[];cleanup=onCleanup(@() removeTemp(out));
   measured=camera41exposure.workflow.prepareDigitizationExposure(files,OutputRoot=out,ROI=roi,AutomaticArea=automatic.Value,LightSetup=string(light.Value),BaseFogNote=string(note.Value));
   for j=1:4,coords{j}.Value=measured.ROI(j);end
   t=readtable(fullfile(out,'exposure_summary.csv'));
   [displayTable,reportLines]=camera41exposure.explainResults(t,measured);summary.Data=displayTable;summary.ColumnName=displayTable.Properties.VariableNames;summary.ColumnWidth={150,65,65,85,110,350};
   analysisTable=t;result=measured;
   channels=["R","G1","G2","B"];signals=zeros(height(t),4);margins=signals;
   for j=1:4,signals(:,j)=t.(char("MedianSignalCodes_"+channels(j)));margins(:,j)=t.(char("HeadroomEV_"+channels(j)));end
   semilogx(signalAxes,t.ShutterSeconds,signals,'o-');grid(signalAxes,'on');xlabel(signalAxes,'Exposure time (s)');ylabel(signalAxes,'RAW signal (codes)');legend(signalAxes,channels,'Location','best');title(signalAxes,'RAW measurements in the same film-base area');
   semilogx(marginAxes,t.ShutterSeconds,margins,'o-');hold(marginAxes,'on');yline(marginAxes,1/3,'--');hold(marginAxes,'off');grid(marginAxes,'on');xlabel(marginAxes,'Exposure time (s)');ylabel(marginAxes,'Clipping margin (EV)');legend(marginAxes,channels,'Location','best');
   views.SelectedTab=comparisonTab;
   passing=find(string(t.Status)=="PASS");chosen.ItemsData={};
   if isempty(passing),chosen.Items={'No passing exposure'};chosen.ItemsData={''};
   else
    chosen.Items=cellstr(compose('%.8g s',t.ShutterSeconds(passing))+" — "+string(t.RAWFile(passing)));chosen.ItemsData=cellstr(string(passing));
    pick=find(t.ShutterSeconds(passing)==result.Selection.CandidateShutterSeconds,1);if isempty(pick),pick=1;end;chosen.Value=char(string(passing(pick)));
   end

   status.Value=cellstr(reportLines);camera41exposure.logEvent('analysis.complete',struct('Seconds',toc(analysisTimer),'Selection',result.Selection,'Measurements',table2struct(t)));
  catch err
   if strcmp(err.identifier,'Camera41:Exposure:FBFStructure')
    manualRequired=true;manualReady=false;manualReason=string(err.message);
    hit=find(startsWith(string(err.message),files+":"),1);if ~isempty(hit),selected=hit;end
    camera41exposure.logEvent('roi.manual_required',struct('Reason',err.message));
    clear done;clear cleanup;showPreview();
   else,report(err);end
  end
 end
 function saveReport(~,~)
  camera41exposure.logEvent('report.save.request',struct());
  [name,folder]=camera41exposure.fileDialog("save",f,'*.json','Save full exposure report, including FAIL results','exposure_report.json');if isequal(name,0),return;end
  try
   saved=result;saved.Measurements=table2struct(analysisTable);[~,lines]=camera41exposure.explainResults(analysisTable,result);saved.Report=cellstr(lines);
   saved.OutputFiles=struct('Scope','Self-contained measurement report; no exposure selected.');
   fid=fopen(fullfile(string(folder),string(name)),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(saved));camera41exposure.logEvent('report.saved',struct('Selection',saved.Selection));
  catch err,report(err);end
 end
 function saveResult(~,~)
  [name,folder]=camera41exposure.fileDialog("save",f,'*.json','Save digitising-camera exposure result','exposure_preparation.json');if isequal(name,0),return;end
  try,saveTo(fullfile(string(folder),string(name)));catch err,report(err);end
 end
 function saveTo(file)
  camera41exposure.logEvent('selection.save.begin',struct('File',string(file)));
  assert(~isempty(result) && chosen.Enable=="on",'Analyse and select a passing exposure first.');
  index=str2double(chosen.Value);assert(string(analysisTable.Status(index))=="PASS",'Select a measured passing time.');
  saved=result;saved.OperatorSelection=struct('ShutterSeconds',analysisTable.ShutterSeconds(index), ...
   'RAWFile',char(string(analysisTable.RAWFile(index))),'Status','OPERATOR_SELECTED_MEASURED_PASS', ...
   'QualificationCreated',false);
  saved.Measurements=table2struct(analysisTable);
  saved.OutputFiles=struct('Scope','Measurements embedded in this JSON; no external analysis folder required.');
  fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'Could not save JSON.');cleanup=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(saved));
  camera41exposure.logEvent('selection.saved',struct('File',string(file),'Selection',saved.OperatorSelection));
  status.Value=cellstr(["Selected digitising-camera time: "+saved.OperatorSelection.ShutterSeconds+" s";"Saved: "+string(file);"Import this JSON in PRE tab 7. PRE embeds it in the film characterisation; no separate JSON import in NEG is needed."]);
 end
 function report(err)
  camera41exposure.logEvent('error',struct('Identifier',err.identifier,'Message',err.message,'Report',getReport(err,'extended','hyperlinks','off')));
  status.Value={err.message};if options.Visible=="on",camera41exposure.alertFocus(f,err.message,'Exposure setup');else,rethrow(err);end
 end
 function closeApp(~,~)
  camera41exposure.logEvent('window.close.request',struct('Running',running));
  if running,status.Value={'Wait for the RAW operation to finish before closing.'};return;end;camera41exposure.logEvent('window.closed',struct());delete(f);
 end
end
function removeTemp(folder)
if isfolder(folder),rmdir(folder,'s');end
end
