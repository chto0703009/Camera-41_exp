function file=logEvent(event,details)
%LOGEVENT Append one timestamped JSON record; logging must not stop the app.
arguments,event (1,1) string,details (1,1) struct=struct(),end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
file=fullfile(root,'logs','camera41_det.jsonl');
try
 if ~isfolder(fileparts(file)),mkdir(fileparts(file));end
 record=struct('TimeUTC',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSSXXX")), ...
  'Event',event,'ProcessID',feature('getpid'),'Details',details);
 fid=fopen(file,'a','n','UTF-8');if fid<0,return;end
 cleanup=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(record));
catch
 % Diagnostic logging must never prevent measurement or saving.
end
end
