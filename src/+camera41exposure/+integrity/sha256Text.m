function digest = sha256Text(value)
%SHA256TEXT SHA-256 of exact UTF-8 text.

arguments
    value (1,1) string
end
md = java.security.MessageDigest.getInstance("SHA-256");
md.update(unicode2native(char(value), "UTF-8"));
digest = lower(join(compose("%02x", typecast(md.digest(), "uint8")), ""));
end
