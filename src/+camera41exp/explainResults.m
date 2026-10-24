function [view,lines]=explainResults(t,result)
%EXPLAINRESULTS Explain measured failures without treating them as read errors.
n=height(t);names=strings(n,1);reason=names;clipped=zeros(n,1);
channels=["R","G1","G2","B"];lines=["RAW decoding succeeded. The exposure assessment is shown below."; ...
 "Measurement area [x y width height]: "+string(mat2str(result.ROI)); ...
 "Requirement: at least "+result.Policy.PassMarginEV+" EV headroom; less than "+100*result.Policy.FailFraction+" % at or above the linearity limit in each channel."];
for k=1:n
 [~,name,ext]=fileparts(string(t.RAWFile(k)));names(k)=name+ext;
 details=strings(4,1);bad=strings(0,1);
 for j=1:4
  fraction=t.(char("AboveLinearityFraction_"+channels(j)))(k);margin=t.(char("HeadroomEV_"+channels(j)))(k);
  clipped(k)=max(clipped(k),100*fraction);
  details(j)=sprintf('%s: signal %.1f codes; headroom %.3f EV; at or above the limit %.4f %%',channels(j),t.(char("MedianSignalCodes_"+channels(j)))(k),margin,100*fraction);
  if fraction>=result.Policy.FailFraction,bad(end+1)=channels(j);end
 end
 if string(t.Status(k))=="FAIL"
  reason(k)="Signal too high in "+join(bad,', ')+". Try a shorter exposure time.";
 elseif string(t.Status(k))=="REVIEW"
  reason(k)="Clipping is within the limit, but headroom is below the required margin. Try a slightly shorter exposure time.";
 else,reason(k)="Required headroom met in all channels.";end
 lines=[lines;"";names(k)+" — "+t.ShutterSeconds(k)+" s — "+string(t.Status(k));reason(k);details];
end
view=table(names,t.ShutterSeconds,string(t.Status),t.MinimumHeadroomEV,clipped,reason, ...
 'VariableNames',{'RAW','Time_s','Status','Headroom_EV','AtOrAboveLimit_percent','Explanation'});
if isfield(result,'Selection')
 s=result.Selection;lines=[lines;"";"Series review: "+string(s.Status);"Proportionality: "+string(s.Linearity.Status)];
 if ~isempty(s.CandidateShutterSeconds),lines=[lines;"Suggested measured time: "+s.CandidateShutterSeconds+" s"];end
 if ~isempty(s.SuggestedNextShutterSeconds),lines=[lines;"Suggested next test: "+s.SuggestedNextShutterSeconds+" s"];end
end
if n==1,lines=[lines;"";"One image assesses only the selected exposure time. Add images at other times for comparison and a linearity check."];end
if all(string(t.Status)~="PASS"),lines=[lines;"No passing exposure time can be selected. First check that the measurement area contains clean film base + fog, then try shorter times."];
else,lines=[lines;"Select a passing exposure time. Then capture the current film base + fog and two matching dark frames at that time, and import them into PRE."];end
lines=[lines;"Automatic measurement avoids the image edges. The yellow area is shown in RAW preview; clear deviations require manual adjustment.";"Comparison curves appear in the Exposure comparison tab. The report and measurements are also available in the application log."];
end
