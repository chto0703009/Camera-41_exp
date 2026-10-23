function [roi,check]=automaticArea(mosaic)
%AUTOMATICAREA Central 70% of native visible sensels; assess structure per CFA.
[h,w]=size(mosaic);assert(min(h,w)>=40,'RAW image is too small for an automatic area.');
x=1+floor(.15*w);y=1+floor(.15*h);roi=[x y w-2*(x-1) h-2*(y-1)];
region=mosaic(y:y+roi(4)-1,x:x+roi(3)-1);residual=zeros(1,4);rangeEV=residual;medianSignal=residual;k=0;
for a=1:2
 for b=1:2
  k=k+1;v=double(region(a:2:end,b:2:end));medianSignal(k)=median(v(:));
  if medianSignal(k)<=1e-5,continue;end
  yy=round(linspace(1,size(v,1)+1,13));xx=round(linspace(1,size(v,2)+1,13));tile=zeros(12);
  for r=1:12,for c=1:12,block=v(yy(r):yy(r+1)-1,xx(c):xx(c+1)-1);tile(r,c)=median(block(:));end,end
  z=log2(max(tile,1e-8));[X,Y]=meshgrid(linspace(-1,1,12));A=[ones(144,1) X(:) Y(:) X(:).^2 X(:).*Y(:) Y(:).^2];
  fit=A*(A\z(:));residual(k)=prctile(abs(z(:)-fit),95);rangeEV(k)=prctile(z(:),95)-prctile(z(:),5);
 end
end
reasons=strings(0,1);
if any(medianSignal<=1e-5),reasons(end+1)="Signalen är för låg för att bedöma en jämn FB+F-yta.";end
if any(residual>.18),reasons(end+1)="Struktur eller ojämnheter avviker från en jämn tom FB+F-exponering.";end
if any(rangeEV>1),reasons(end+1)="Ljusskillnaden inom det föreslagna området överstiger 1 EV.";end
check=struct('ROI',roi,'NeedsManualReview',~isempty(reasons),'Reasons',{cellstr(reasons)}, ...
 'Residual95EV',residual,'Range90EV',rangeEV,'BorderFraction',.15,'Scope','Heuristic uniformity screen; cannot identify physical film content with certainty.');
end
