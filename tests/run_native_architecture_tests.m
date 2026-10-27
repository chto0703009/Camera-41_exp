function run_native_architecture_tests()
% Selection tests use disposable copies, never project or measurement files.
root=string(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(root,'src'));
if ~ismac,fprintf('macOS architecture tests skipped.\n');return;end
fixture=string(tempname);mkdir(fullfile(fixture,'tools','bin'));cleanup=onCleanup(@()rmdir(fixture,'s'));
base=fullfile(fixture,'tools','bin','camera41_raw_probe');
for architecture=["arm64","x86_64"]
 copyfile(fullfile(root,'tools','bin',"camera41_raw_probe_"+architecture),base+"_"+architecture);
 [selected,actual]=camera41exp.runtime.rawProbeExecutable(Architecture=architecture,Root=fixture);
 assert(selected==base+"_"+architecture && actual==architecture);
 % Unsuffixed fallback is valid only when its contents match.
 copyfile(base+"_"+architecture,base);delete(base+"_"+architecture);
 assert(camera41exp.runtime.rawProbeExecutable(Architecture=architecture,Root=fixture)==base);
 other="arm64";if architecture=="arm64",other="x86_64";end
 copyfile(fullfile(root,'tools','bin',"camera41_raw_probe_"+other),base);
 rejected=false;
 try,camera41exp.runtime.rawProbeExecutable(Architecture=architecture,Root=fixture);catch failure,rejected=strcmp(failure.identifier,'Camera41:Runtime:MissingRawProbe');end
 assert(rejected,'Wrong-architecture fallback was accepted.');
 % A matching filename cannot disguise the wrong binary.
 copyfile(base,base+"_"+architecture);
 rejected=false;
 try,camera41exp.runtime.rawProbeExecutable(Architecture=architecture,Root=fixture);catch failure,rejected=strcmp(failure.identifier,'Camera41:Runtime:MissingRawProbe');end
 assert(rejected);delete(base+"_"+architecture);
end
report=camera41exp.runtime.ensureRawProbe();physical=camera41exp.runtime.nativeArchitecture();
assert(string(report.ProbeArchitecture)==physical.Physical);
% System Perl includes arm64e slices on newer macOS.
[status,output]=camera41exp.runtime.invoke('/usr/bin/perl',["-e","print join(q{|}, @ARGV)","å ä ü spaces","literal $()`"],15);
assert(status==0 && output=="å ä ü spaces|literal $()`");
script=fullfile(fixture,'native exiftool');fid=fopen(script,'w');fprintf(fid,'#!/usr/bin/perl\nprint join(q{|}, @ARGV);\n');fclose(fid);
[command,args]=camera41exp.runtime.nativeCommand(script,"å ä ü spaces");
assert(command=="/usr/bin/arch" && args(1)=="-"+physical.Physical);
[status,output]=camera41exp.runtime.invoke(script,"å ä ü spaces",15);assert(status==0 && output=="å ä ü spaces");
fid=fopen(script,'w');fprintf(fid,'#!/usr/bin/env perl\nprint join(q{|}, @ARGV);\n');fclose(fid);
[command,args]=camera41exp.runtime.nativeCommand(script,"env test");assert(~endsWith(args(2),"/env"));
[status,output]=camera41exp.runtime.invoke(script,"env test",15);assert(status==0 && output=="env test");
fprintf('Native architecture selection, fallback rejection, LibRaw and Perl tests passed (%s).\n',physical.Physical);
end
