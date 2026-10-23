function paths=selectedPaths(folder,names)
%SELECTEDPATHS Normalize single character filenames and multiselect cell arrays.
if isequal(names,0),paths=strings(0,1);return;end
names=string(names);paths=fullfile(string(folder),names(:));
end
