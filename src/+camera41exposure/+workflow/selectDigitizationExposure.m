function selection=selectDigitizationExposure(times,statuses,signals,options)
%SELECTDIGITIZATIONEXPOSURE Conservative FB+F bracket and linear-response review.
% signals: N-by-4 median black-subtracted R/G1/G2/B codes, never JPEG values.
arguments
 times (:,1) double {mustBePositive,mustBeFinite}
 statuses (:,1) string
 signals (:,4) double {mustBeFinite}
 options.LinearityTolerance (1,1) double {mustBePositive,mustBeFinite}=0.05
end
assert(numel(times)==numel(statuses) && size(signals,1)==numel(times));
assert(all(ismember(statuses,["PASS","REVIEW","FAIL"])));
u=unique(times);passed=false(size(u));level=zeros(numel(u),4);
for k=1:numel(u)
 ix=times==u(k);passed(k)=all(statuses(ix)=="PASS");level(k,:)=median(signals(ix,:),1);
end
selection=struct('Status','NO_PASSING_EXPOSURE','CandidateShutterSeconds',[], ...
 'SuggestedNextShutterSeconds',[],'HasMeasuredNoise',false,'ProductionAcceptanceImplied',false, ...
 'Linearity',struct('Status','INSUFFICIENT_PASSING_TIMES','ToleranceFraction',options.LinearityTolerance, ...
 'MaximumRelativeDeviationRG1G2B',[],'DistinctPassingTimes',sum(passed)));
best=find(passed,1,'last');if isempty(best),return;end
selection.CandidateShutterSeconds=u(best);
upper=find(~passed & u>u(best),1,'first');
if isempty(upper)
 selection.Status='PROVISIONAL_ADD_HIGHER_EXPOSURE';selection.SuggestedNextShutterSeconds=u(best)*2^(1/3);
elseif log2(u(upper)/u(best))>1/3+1e-9
 selection.Status='PROVISIONAL_REFINE_BRACKET';selection.SuggestedNextShutterSeconds=sqrt(u(best)*u(upper));
else
 selection.Status='HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY';
end
% Compare signal/time only where all channels passed, never saturated values.
if sum(passed)>=3 && max(u(passed))/min(u(passed))>=2
 slopes=level(passed,:)./u(passed);reference=median(slopes,1);
 if any(reference<=0)
  selection.Linearity.Status='REVIEW_NONPOSITIVE_SIGNAL';
 else
  deviation=max(abs(slopes./reference-1),[],1);
  selection.Linearity.MaximumRelativeDeviationRG1G2B=deviation;
  if all(deviation<=options.LinearityTolerance)
   selection.Linearity.Status='PROPORTIONALITY_CHECK_PASS';
  else
   selection.Linearity.Status='REVIEW_NONPROPORTIONAL_RESPONSE';
  end
 end
end
if startsWith(string(selection.Linearity.Status),'REVIEW_')
 selection.Status='REVIEW_LINEAR_RESPONSE_BEFORE_USING_CANDIDATE';
end
end
