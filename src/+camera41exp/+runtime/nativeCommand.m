function [executable,args]=nativeCommand(executable,args)
%NATIVECOMMAND Run matching Mach-O slices and Perl scripts on physical hardware.
arguments
 executable (1,1) string
 args (1,:) string
end
if ~ismac,return;end
% Resolve PATH names before inspecting a script or executable.
if ~isfile(executable) && ~contains(executable,"/")
 for folder=split(string(getenv('PATH')),pathsep)'
  candidate=fullfile(folder,executable);
  if isfile(candidate),executable=candidate;break;end
 end
end
if ~isfile(executable),return;end
fid=fopen(executable,'r');
if fid<0,return;end
cleanup=onCleanup(@()fclose(fid));header=string(char(fread(fid,256,'*uint8')'));clear cleanup
line=extractBefore(header+newline,newline);
if startsWith(line,"#!") && ~isempty(regexp(char(line),'perl(?:[0-9.]*)?(?:\s|$)','once'))
 % ExifTool's script location remains argv[1], preserving its library lookup.
 words=split(strip(extractAfter(line,2)));declared=words(1);
 if endsWith(declared,"/env"),declared="";end
 candidates=[declared,"/usr/bin/perl","/opt/homebrew/bin/perl","/usr/local/bin/perl"];
 found=false;
 for perl=candidates
  info=camera41exp.runtime.nativeArchitecture(perl);
  if info.Native
   flags=strings(1,0);
   if perl==declared && numel(words)>1,flags=reshape(words(2:end),1,[]);end
   args=[flags,executable,args];executable=perl;found=true;break
  end
 end
 assert(found,'Camera41:Runtime:PerlArchitecture','No native Perl interpreter is available for %s.',executable);
end
info=camera41exp.runtime.nativeArchitecture(executable);
if info.Native
 args=["-"+info.Physical,executable,args];executable="/usr/bin/arch";
elseif ~isempty(info.Slices)
 error('Camera41:Runtime:Architecture','Executable %s has no %s slice.',executable,info.Physical);
end
end
