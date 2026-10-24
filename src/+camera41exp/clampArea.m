function roi=clampArea(roi,dimensions)
%CLAMPAREA Integer ROI whose last pixel remains within native visible bounds.
w=dimensions(1);h=dimensions(2);roi=round(reshape(roi,1,4));
roi(1:2)=max([1 1],min(roi(1:2),[w-19 h-19]));
roi(3:4)=max([20 20],min(roi(3:4),[w-roi(1)+1 h-roi(2)+1]));
end
