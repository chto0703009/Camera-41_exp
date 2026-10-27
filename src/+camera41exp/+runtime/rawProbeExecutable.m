function [probe,architecture]=rawProbeExecutable(options)
%RAWPROBEEXECUTABLE Validate slices before selecting a native LibRaw executable.
arguments
 options.Architecture (1,1) string {mustBeMember(options.Architecture,["auto","arm64","x86_64"])}="auto"
 options.Root (1,1) string=""
end
root=options.Root;
if root=="",root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));end
architecture=options.Architecture;
if architecture=="auto"
 info=camera41exp.runtime.nativeArchitecture();architecture=info.Physical;
end
base=fullfile(root,'tools','bin','camera41_raw_probe');
if architecture=="",probe=base;return;end
% Legacy local-config architecture settings must not override physical hardware.
for candidate=[base+"_"+architecture,base]
 if ~isfile(candidate),continue;end
 info=camera41exp.runtime.nativeArchitecture(candidate);
 if any(startsWith(info.Slices,architecture)),probe=candidate;return;end
end
error('Camera41:Runtime:MissingRawProbe','No %s LibRaw executable found in %s. Copy the complete program folder or rebuild on this computer.',architecture,fileparts(base));
end
