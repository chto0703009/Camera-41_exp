function [view,lines]=explainResults(t,result)
%EXPLAINRESULTS Explain measured failures without treating them as read errors.
n=height(t);names=strings(n,1);reason=names;clipped=zeros(n,1);
channels=["R","G1","G2","B"];lines=["RAW-inläsningen lyckades. Nedan visas exponeringsbedömningen."; ...
 "Mätområde [x y bredd höjd]: "+string(mat2str(result.ROI)); ...
 "Krav: minst "+result.Policy.PassMarginEV+" EV marginal; under "+100*result.Policy.FailFraction+" % vid/över linjäritetsgränsen i varje kanal."];
for k=1:n
 [~,name,ext]=fileparts(string(t.RAWFile(k)));names(k)=name+ext;
 details=strings(4,1);bad=strings(0,1);
 for j=1:4
  fraction=t.(char("AboveLinearityFraction_"+channels(j)))(k);margin=t.(char("HeadroomEV_"+channels(j)))(k);
  clipped(k)=max(clipped(k),100*fraction);
  details(j)=sprintf('%s: signal %.1f koder; marginal %.3f EV; vid/över gränsen %.4f %%',channels(j),t.(char("MedianSignalCodes_"+channels(j)))(k),margin,100*fraction);
  if fraction>=result.Policy.FailFraction,bad(end+1)=channels(j);end
 end
 if string(t.Status(k))=="FAIL"
  reason(k)="För hög signal i "+join(bad,', ')+". Prova kortare exponeringstid.";
 elseif string(t.Status(k))=="REVIEW"
  reason(k)="Ingen underkänd klippning, men mindre än önskad marginal. Prova något kortare tid.";
 else,reason(k)="Godkänd marginal i samtliga kanaler.";end
 lines=[lines;"";names(k)+" — "+t.ShutterSeconds(k)+" s — "+string(t.Status(k));reason(k);details];
end
view=table(names,t.ShutterSeconds,string(t.Status),t.MinimumHeadroomEV,clipped,reason, ...
 'VariableNames',{'RAW','Tid_s','Status','Marginal_EV','OverGransen_procent','Forklaring'});
if n==1,lines=[lines;"";"En bild bedömer bara den valda tiden. Lägg till bilder med andra tider för jämförelse och linjäritetskontroll."];end
if all(string(t.Status)~="PASS"),lines=[lines;"Ingen godkänd tid kan väljas. Kontrollera först att mätområdet ligger på ren filmbas + slöja, och prova kortare tider."];
else,lines=[lines;"Välj en godkänd tid. Ta sedan aktuell films FB+F och två matchande mörkerbilder vid den tiden och läs in dem i PRE."];end
lines=[lines;"Mätområdet undviker bildkanterna i automatiskt läge. Gul ruta visas i RAW preview; tydliga avvikelser kräver manuell justering.";"Jämförelsekurvorna visas i fliken Exposure comparison. Rapporten och mätvärdena finns även i appens logg."];
end
