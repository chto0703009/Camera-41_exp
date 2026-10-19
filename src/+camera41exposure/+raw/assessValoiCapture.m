function report = assessValoiCapture(decoded, roi, options)
%ASSESSVALOICAPTURE Report Valoi exposure headroom and usable sensor bits.
arguments
    decoded (1,1) struct
    roi (1,4) double {mustBeFinite, mustBePositive, mustBeInteger}
    options.DarkDecoded cell = {}
    options.PassMarginEV (1,1) double {mustBeNonnegative, mustBeFinite} = 1/3
    options.FailFraction (1,1) double {mustBeNonnegative, mustBeLessThanOrEqual(options.FailFraction,1)} = 1e-4
end

assessment = camera41exposure.raw.checkFilmBaseExposure( ...
    decoded, roi, PassMarginEV=options.PassMarginEV, ...
    FailFraction=options.FailFraction);
levelOrder = [1 2 4 3];
black = reshape(double(decoded.LibRaw.black_level_channels(levelOrder)), 1, 4);
limit = reshape(double(decoded.LibRaw.linearity_limits(levelOrder)), 1, 4);
codeRange = limit - black;
codeRangeBits = log2(codeRange);
medianLinear = [assessment.Channels.MedianLinear];
signalCodes = medianLinear .* codeRange;

noiseSigma = nan(1, 4);
dynamicRangeBits = nan(1, 4);
signalAboveNoiseBits = nan(1, 4);
if ~isempty(options.DarkDecoded)
    assert(numel(options.DarkDecoded) == 2, ...
        "Camera41:Valoi:DarkPairRequired", ...
        "Provide either no dark captures or exactly two matched dark captures.");
    validateMatchedCapture(decoded, options.DarkDecoded{1});
    validateMatchedCapture(decoded, options.DarkDecoded{2});
    noiseSigma = temporalNoise(options.DarkDecoded{1}, ...
        options.DarkDecoded{2}, roi);
    dynamicRangeBits = log2(codeRange ./ noiseSigma);
    signalAboveNoiseBits = log2(max(signalCodes ./ noiseSigma, realmin));
end

names = ["R", "G1", "G2", "B"];
channels = repmat(struct("Channel", "", "CodeRange", 0, ...
    "CodeRangeBits", 0, "MedianSignalCodes", 0, ...
    "HeadroomEV", 0, "NoiseSigmaCodes", NaN, ...
    "EffectiveDynamicRangeBits", NaN, ...
    "MedianSignalAboveNoiseBits", NaN), 4, 1);
for index = 1:4
    channels(index) = struct("Channel", names(index), ...
        "CodeRange", codeRange(index), ...
        "CodeRangeBits", codeRangeBits(index), ...
        "MedianSignalCodes", signalCodes(index), ...
        "HeadroomEV", assessment.Channels(index).MarginEVAt999, ...
        "NoiseSigmaCodes", noiseSigma(index), ...
        "EffectiveDynamicRangeBits", dynamicRangeBits(index), ...
        "MedianSignalAboveNoiseBits", signalAboveNoiseBits(index));
end

report = struct("Schema", "camera41.valoi-exposure-report.v0.3", ...
    "Status", assessment.Status, "Source", decoded.Source, ...
    "CameraSettings", struct("ISO", decoded.LibRaw.iso, ...
        "ShutterSeconds", decoded.LibRaw.shutter_seconds, ...
        "Aperture", decoded.LibRaw.aperture), ...
    "ROI", assessment.ROI, "ExposureAssessment", assessment, ...
    "Channels", channels, "HasMatchedDarkPair", ...
        ~isempty(options.DarkDecoded), ...
    "Interpretation", interpretation(assessment.Status));

fprintf("\nCamera-41 Valoi exposure: %s\n", report.Status);
fprintf("  ISO %.0f, 1/%.3g s, f/%.3g\n", decoded.LibRaw.iso, ...
    1 / decoded.LibRaw.shutter_seconds, decoded.LibRaw.aperture);
fprintf("  Channel  headroom   code bits");
if report.HasMatchedDarkPair, fprintf("   effective bits   signal/noise bits"); end
fprintf("\n");
for index = 1:4
    fprintf("  %-3s      %6.3f      %6.2f", names(index), ...
        channels(index).HeadroomEV, channels(index).CodeRangeBits);
    if report.HasMatchedDarkPair
        fprintf("          %6.2f              %6.2f", ...
            channels(index).EffectiveDynamicRangeBits, ...
            channels(index).MedianSignalAboveNoiseBits);
    end
    fprintf("\n");
end
fprintf("  %s\n", report.Interpretation);
end

function validateMatchedCapture(source, dark)
assert(string(dark.Schema) == "camera41.raw-decode.v0.2" && ...
    string(dark.Status) == "VALID", "Camera41:Valoi:InvalidDark", ...
    "Dark captures must be valid Camera-41 RAW decodes.");
assert(dark.CameraIdentity.BodyIdentifierSHA256 == ...
    source.CameraIdentity.BodyIdentifierSHA256 && ...
    dark.LibRaw.iso == source.LibRaw.iso && ...
    abs(dark.LibRaw.shutter_seconds-source.LibRaw.shutter_seconds) < 1e-7 && ...
    abs(dark.LibRaw.aperture-source.LibRaw.aperture) < 1e-12, ...
    "Camera41:Valoi:DarkNotMatched", ...
    "Dark captures must match camera body, ISO, shutter and aperture.");
end

function sigma = temporalNoise(first, second, roi)
firstMosaic = readVisible(first);
secondMosaic = readVisible(second);
x = roi(1); y = roi(2); width = roi(3); height = roi(4);
difference = (double(firstMosaic(y:y+height-1, x:x+width-1)) - ...
    double(secondMosaic(y:y+height-1, x:x+width-1))) ./ sqrt(2);
rowPhase = mod(y - 1, 2) + 1;
columnPhase = mod(x - 1, 2) + 1;
positions = [1 1; 1 2; 2 1; 2 2];
sigma = zeros(1, 4);
for index = 1:4
    localRow = mod(positions(index, 1)-rowPhase, 2)+1;
    localColumn = mod(positions(index, 2)-columnPhase, 2)+1;
    values = difference(localRow:2:end, localColumn:2:end);
    center = median(values, "all");
    sigma(index) = 1.4826 * median(abs(values-center), "all");
end
end

function visible = readVisible(decoded)
filename = fullfile(decoded.ResultFolder, string(decoded.Outputs.MosaicFile));
fid = fopen(filename, "r", "ieee-le");
assert(fid >= 0, "Camera41:Valoi:MosaicMissing", ...
    "Decoded Bayer mosaic cannot be read: %s", filename);
cleanup = onCleanup(@() fclose(fid));
raw = fread(fid, [decoded.LibRaw.raw_width decoded.LibRaw.raw_height], ...
    "uint16=>uint16").';
rows = decoded.LibRaw.top_margin + (1:decoded.LibRaw.visible_height);
columns = decoded.LibRaw.left_margin + (1:decoded.LibRaw.visible_width);
visible = raw(rows, columns);
clear cleanup
end

function value = interpretation(status)
switch string(status)
    case "PASS"
        value = "PASS: no clipping and the required linearity margin remains.";
    case "REVIEW"
        value = "REVIEW: no failure, but exposure should not be increased.";
    otherwise
        value = "FAIL: reduce exposure and capture a new base+fog RAW.";
end
end
