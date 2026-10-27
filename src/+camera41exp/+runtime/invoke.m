function [status,output]=invoke(executable,args,timeout)
%INVOKE Separate process arguments; no shell interpolation or MATLAB pyenv.
arguments
 executable (1,1) string
 args (1,:) string
 timeout (1,1) double=300
end
[executable,args]=camera41exp.runtime.nativeCommand(executable,args);
log=string(tempname)+".log";cleanup=onCleanup(@() remove(log));
list=javaObject('java.util.ArrayList');list.add(javaObject('java.lang.String',char(executable)));
for value=args,list.add(javaObject('java.lang.String',char(value)));end
builder=javaObject('java.lang.ProcessBuilder',list);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(char(log)));
process=builder.start();finished=process.waitFor(int64(timeout),java.util.concurrent.TimeUnit.SECONDS);
if ~finished,process.destroyForcibly();process.waitFor();status=124;else,status=double(process.exitValue());end
output=string(fileread(log));
end
function remove(file),if isfile(file),delete(file);end,end
