function report=ensureRawProbe()
%ENSURERAWPROBE Verify native support and offer a local rebuild if needed.
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
[probe,architecture]=camera41exp.runtime.rawProbeExecutable();
try
 report=check(probe,architecture);return
catch failure
 choice="";
 if usejava('desktop')
  choice=string(questdlg(sprintf(['LibRaw support could not start on this computer.\n\n' ...
   'Prepare rebuilds support locally and requires LibRaw, pkg-config and a compiler.\n\n%s'],failure.message), ...
   'Prepare for this computer','Prepare','Cancel','Prepare'));
 end
 if choice~="Prepare"
  throwAsCaller(MException('Camera41:Runtime:PreparationRequired', ...
   'LibRaw needs preparation. Run tools/build_raw_probe.sh on this computer.\n%s',failure.message));
 end
end
assert(isunix,'Camera41:Runtime:Platform','The bundled LibRaw build script requires macOS or Unix.');
fprintf('Preparing LibRaw for this computer...\n');drawnow;
[status,output]=camera41exp.runtime.invoke("/bin/sh",fullfile(root,'tools','build_raw_probe.sh'),300);
assert(status==0,'Camera41:Runtime:Build','LibRaw preparation failed. Install LibRaw, pkg-config and a compiler, then retry.\n%s',output);
[probe,architecture]=camera41exp.runtime.rawProbeExecutable();report=check(probe,architecture);
end
function report=check(probe,architecture)
assert(isfile(probe),'Camera41:Runtime:MissingRawProbe','LibRaw executable missing: %s',probe);
[status,output]=camera41exp.runtime.invoke(probe,"--build-info",30);
assert(status==0,'Camera41:Runtime:RawProbe','LibRaw could not start: %s',output);
report=jsondecode(output);
assert(isfield(report,'ProbeArchitecture') && (architecture=="" || string(report.ProbeArchitecture)==architecture), ...
 'Camera41:Runtime:Architecture','LibRaw does not match this computer (%s).',architecture);
end
