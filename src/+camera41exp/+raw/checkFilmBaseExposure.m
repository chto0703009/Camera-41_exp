function assessment = checkFilmBaseExposure(decoded, roi, options)
%CHECKFILMBASEEXPOSURE Assess clear film/base+fog exposure in sensor space.
%
% assessment = camera41exp.raw.checkFilmBaseExposure(decoded, [x y w h])

arguments
    decoded (1,1) struct
    roi (1,4) double {mustBeFinite, mustBePositive, mustBeInteger}
    options.PassMarginEV (1,1) double {mustBeNonnegative, mustBeFinite} = 1/3
    options.FailFraction (1,1) double {mustBeInRange(options.FailFraction,0,1)} = 1e-4
end

if ~isfield(decoded, "Schema") || ...
        string(decoded.Schema) ~= "camera41.raw-decode.v0.2" || ...
        string(decoded.Status) ~= "VALID"
    error("Camera41:FilmBase:InvalidDecode", ...
        "Input must be a VALID result returned by camera41exp.raw.decode.");
end
required = ["ResultFolder", "Outputs", "LibRaw"];
if ~all(isfield(decoded, required))
    error("Camera41:FilmBase:IncompleteDecode", ...
        "Decoded result is missing required provenance or output fields.");
end

linearFile = fullfile(decoded.ResultFolder, ...
    string(decoded.Outputs.LinearSensorFile));
if ~isfile(linearFile)
    error("Camera41:FilmBase:LinearSensorMissing", ...
        "The decoded linear sensor file is missing.");
end
saved = load(linearFile, "linearMosaic", "blackLevel", ...
    "linearityLimit", "cfaPattern");
if string(saved.cfaPattern) ~= "RGGB"
    error("Camera41:FilmBase:UnsupportedCFA", ...
        "The initial film-base assessment requires RGGB sensor data.");
end

x1 = roi(1); y1 = roi(2);
x2 = x1 + roi(3) - 1; y2 = y1 + roi(4) - 1;
[height, width] = size(saved.linearMosaic);
if x2 > width || y2 > height
    error("Camera41:FilmBase:ROIOutsideSensor", ...
        "ROI must lie inside the visible sensor area %d x %d.", width, height);
end
if roi(3) < 20 || roi(4) < 20
    error("Camera41:FilmBase:ROITooSmall", ...
        "ROI must be at least 20 x 20 visible sensels.");
end

region = double(saved.linearMosaic(y1:y2, x1:x2));
% Preserve CFA phase even when an ROI begins on an even sensor coordinate.
rowPhase = mod(y1 - 1, 2) + 1;
columnPhase = mod(x1 - 1, 2) + 1;
names = ["R", "G1", "G2", "B"];
positions = [1 1; 1 2; 2 1; 2 2];
channels = repmat(struct("Channel", "", "SampleCount", 0, ...
    "MedianLinear", 0, "Percentile99Linear", 0, ...
    "Percentile999Linear", 0, "MaximumLinear", 0, ...
    "MarginEVAt999", 0, "AboveLinearityFraction", 0, ...
    "Status", ""), 4, 1);
for index = 1:4
    localRow = mod(positions(index, 1) - rowPhase, 2) + 1;
    localColumn = mod(positions(index, 2) - columnPhase, 2) + 1;
    values = region(localRow:2:end, localColumn:2:end);
    values = values(:);
    p99 = prctile(values, 99);
    p999 = prctile(values, 99.9);
    above = mean(values >= 1, "all");
    marginEV = -log2(max(p999, realmin));
    if above >= options.FailFraction
        status = "FAIL";
    elseif marginEV >= options.PassMarginEV
        status = "PASS";
    else
        status = "REVIEW";
    end
    channels(index) = struct("Channel", names(index), ...
        "SampleCount", numel(values), "MedianLinear", median(values, "all"), ...
        "Percentile99Linear", p99, "Percentile999Linear", p999, ...
        "MaximumLinear", max(values, [], "all"), ...
        "MarginEVAt999", marginEV, ...
        "AboveLinearityFraction", above, "Status", status);
end

statuses = string({channels.Status});
if any(statuses == "FAIL")
    overall = "FAIL";
elseif any(statuses == "REVIEW")
    overall = "REVIEW";
else
    overall = "PASS";
end

assessment = struct();
assessment.Schema = "camera41.film-base-exposure-assessment.v0.2";
assessment.Status = overall;
assessment.SourceSHA256 = string(decoded.Source.SHA256);
assessment.DecodeContentSHA256 = string(decoded.ContentSHA256);
assessment.ROI = struct("X", x1, "Y", y1, "Width", roi(3), "Height", roi(4));
assessment.Policy = struct("Percentile", 99.9, ...
    "PassMarginEV", options.PassMarginEV, ...
    "FailFraction", options.FailFraction, ...
    "LinearityReference", "LibRaw linearity limit after black subtraction", ...
    "Status", "CONFIGURABLE_MEASURED_POLICY");
assessment.Channels = channels;
payload = assessment;
assessment.ContentSHA256 = camera41exp.integrity.sha256Text( ...
    camera41exp.integrity.canonicalJSON(payload));

fprintf("Camera-41 film-base exposure: %s\n", overall);
for index = 1:4
    fprintf("  %s: %s, p99.9 %.4f, margin %.3f EV\n", ...
        channels(index).Channel, channels(index).Status, ...
        channels(index).Percentile999Linear, channels(index).MarginEVAt999);
end
end

function mustBeInRange(value, minimum, maximum)
if value < minimum || value > maximum
    error("Camera41:FilmBase:ValueOutsideRange", ...
        "Value must be between %g and %g.", minimum, maximum);
end
end
