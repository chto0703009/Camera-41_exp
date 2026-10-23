function text = canonicalJSON(value)
%CANONICALJSON Canonical JSON for Camera-41 session hashing.
% Implements the RFC 8785 ordering/whitespace rules for Camera-41's JSON-safe
% MATLAB values. Non-finite numbers and unsupported MATLAB classes are refused.

text = encodeValue(value);
end

function text = encodeValue(value)
if isstruct(value)
    if ~isscalar(value)
        parts = strings(numel(value), 1);
        for index = 1:numel(value), parts(index) = encodeValue(value(index)); end
        text = "[" + strjoin(parts, ",") + "]";
        return
    end
    names = sort(string(fieldnames(value)));
    parts = strings(numel(names), 1);
    for index = 1:numel(names)
        name = names(index);
        parts(index) = string(jsonencode(char(name))) + ":" + ...
            encodeValue(value.(char(name)));
    end
    text = "{" + strjoin(parts, ",") + "}";
elseif iscell(value)
    parts = strings(numel(value), 1);
    for index = 1:numel(value), parts(index) = encodeValue(value{index}); end
    text = "[" + strjoin(parts, ",") + "]";
elseif isstring(value)
    if isscalar(value)
        if ismissing(value), text = "null"; else, text = string(jsonencode(char(value))); end
    else
        parts = arrayfun(@(item) encodeValue(item), value(:), UniformOutput=false);
        text = "[" + strjoin(string(parts), ",") + "]";
    end
elseif ischar(value)
    text = string(jsonencode(value));
elseif islogical(value)
    if isscalar(value)
        if value, text = "true"; else, text = "false"; end
    else
        text = encodeNumericArray(value);
    end
elseif isnumeric(value)
    if any(~isfinite(value), "all")
        error("Camera41:Integrity:NonFiniteJSON", ...
            "Canonical JSON refuses NaN and infinite numeric values.");
    end
    if isempty(value)
        text = "[]";
    elseif isscalar(value)
        text = string(jsonencode(value));
        if text == "-0", text = "0"; end
    else
        text = encodeNumericArray(value);
    end
else
    error("Camera41:Integrity:UnsupportedJSONType", ...
        "Unsupported canonical JSON class: %s", class(value));
end
end

function text = encodeNumericArray(value)
% Session vectors are JSON arrays independent of MATLAB row/column shape.
parts = strings(numel(value), 1);
for index = 1:numel(value), parts(index) = encodeValue(value(index)); end
text = "[" + strjoin(parts, ",") + "]";
end
