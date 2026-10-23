function [probe,architecture]=rawProbeExecutable(options)
%RAWPROBEEXECUTABLE Prefer the physical Mac architecture, including under Rosetta.
arguments
 options.Architecture (1,1) string {mustBeMember(options.Architecture,["auto","arm64","x86_64"])}="auto"
end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
architecture=options.Architecture;
if architecture=="auto"
 persistent nativeMacArchitecture
 if isempty(nativeMacArchitecture)
  if ismac
   [status,result]=system('/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null');
   if status==0 && strip(string(result))=="1",nativeMacArchitecture="arm64";else,nativeMacArchitecture="x86_64";end
  else
   nativeMacArchitecture="";
  end
 end
 architecture=nativeMacArchitecture;
end
probe=fullfile(root,'tools','bin','camera41_raw_probe');
if architecture~=""
 candidate=probe+"_"+architecture;
 if isfile(candidate),probe=candidate;end
end
end
