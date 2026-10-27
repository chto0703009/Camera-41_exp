function result = decode(rawFile, options)
%DECODE Verify and extract an undemosaiced LibRaw Bayer sensor result.

arguments
    rawFile (1,1) string
    options.OutputRoot (1,1) string
    options.CompressSensorFile (1,1) logical=true
    options.ExpectedSHA256 (1,1) string = ""
    options.ProbeExecutable (1,1) string = ""
end

rawFile = canonicalPath(rawFile);
if ~isfile(rawFile)
    error("Camera41:Raw:SourceMissing", "RAW source not found: %s", rawFile);
end
sourceBefore = fileRecord(rawFile);
if options.ExpectedSHA256 ~= "" && ...
        sourceBefore.SHA256 ~= lower(options.ExpectedSHA256)
    error("Camera41:Raw:SourceHashMismatch", ...
        "RAW source SHA-256 does not match the expected fixture identity.");
end

probe = options.ProbeExecutable;
if probe == ""
    probe = camera41exp.runtime.rawProbeExecutable();
end
if ~isfile(probe)
    error("Camera41:Raw:ProbeMissing", ...
        "Build the LibRaw probe with tools/build_raw_probe.sh.");
end

outputRoot = canonicalPath(options.OutputRoot);
if ~isfolder(outputRoot), mkdir(outputRoot); end
runID = lower(string(char(java.util.UUID.randomUUID())));
resultFolder = fullfile(outputRoot, "Camera41_raw_" + runID);
mkdir(resultFolder);
resultCleanup = onCleanup(@() cleanupFailedResult(resultFolder));
metadataFile = fullfile(resultFolder, "libraw_metadata.json");
mosaicFile = fullfile(resultFolder, "bayer_mosaic.raw16le");

[status, output] = camera41exp.runtime.invoke(probe,[string(rawFile),string(metadataFile),string(mosaicFile)],300);
if status ~= 0
    error("Camera41:Raw:LibRawFailed", ...
        "LibRaw probe failed (%d):\n%s", status, output);
end
metadata = jsondecode(fileread(metadataFile));
validateMetadata(metadata);
mosaicInfo = dir(mosaicFile);
if isempty(mosaicInfo) || mosaicInfo.bytes ~= metadata.sample_count * 2
    error("Camera41:Raw:MosaicSizeMismatch", ...
        "Extracted mosaic byte size differs from LibRaw metadata.");
end

fid = fopen(mosaicFile, "r", "ieee-le");
if fid < 0
    error("Camera41:Raw:MosaicReadFailed", "Cannot read extracted mosaic.");
end
cleanup = onCleanup(@() fclose(fid));
mosaic = fread(fid, [metadata.raw_width metadata.raw_height], ...
    "uint16=>uint16").';
clear cleanup
if numel(mosaic) ~= metadata.sample_count
    error("Camera41:Raw:MosaicSizeMismatch", ...
        "Extracted mosaic size differs from LibRaw metadata.");
end

rows = metadata.top_margin + (1:metadata.visible_height);
columns = metadata.left_margin + (1:metadata.visible_width);
visible = mosaic(rows, columns);
black = double(metadata.black_level_channels(:).');
linearity = double(metadata.linearity_limits(:).');
if string(metadata.cfa_visible_2x2) ~= "RGGB"
    error("Camera41:Raw:UnsupportedCFA", ...
        "The initial v0.2 implementation currently requires RGGB input.");
end
% LibRaw level arrays are R,G,B,G2; visible RGGB mosaic positions are R,G,G2,B.
levelOrder = [1 2 4 3];
black = black(levelOrder);
linearity = linearity(levelOrder);
[statistics, linearMosaic] = sensorStatistics(visible, black, linearity);

linearFile = fullfile(resultFolder, "linear_sensor.mat");
cfaPattern = string(metadata.cfa_visible_2x2);
blackLevel = black;
linearityLimit = linearity;
sourceSHA256 = sourceBefore.SHA256;
if options.CompressSensorFile
 save(linearFile, "linearMosaic", "cfaPattern", "blackLevel", "linearityLimit", "sourceSHA256", "-v7.3");
else
 save(linearFile, "linearMosaic", "cfaPattern", "blackLevel", "linearityLimit", "sourceSHA256", "-v7.3", "-nocompression");
end

sourceAfter = fileRecord(rawFile);
if ~isequal(sourceBefore, sourceAfter)
    error("Camera41:Raw:SourceModified", ...
        "RAW source changed during decoding.");
end

result = struct();
result.Schema = "camera41.raw-decode.v0.2";
result.Status = "VALID";
result.Source = sourceBefore;
result.LibRaw = metadata;
identity = struct("Make", string(metadata.make), ...
    "Model", string(metadata.model), ...
    "BodySerial", string(metadata.body_serial), ...
    "InternalBodySerial", string(metadata.internal_body_serial), ...
    "LensMake", string(metadata.lens_make), ...
    "LensModel", string(metadata.lens_model), ...
    "LensSerial", string(metadata.lens_serial), ...
    "InternalLensSerial", string(metadata.internal_lens_serial));
identity.PhysicalBodyIdentified = identity.BodySerial ~= "" || ...
    identity.InternalBodySerial ~= "";
identity.BodyIdentifierSHA256 = camera41exp.integrity.sha256Text( ...
    camera41exp.integrity.canonicalJSON(struct("Make", identity.Make, ...
    "Model", identity.Model, "BodySerial", identity.BodySerial, ...
    "InternalBodySerial", identity.InternalBodySerial)));
result.CameraIdentity = identity;
result.Processing = struct( ...
    "Demosaiced", false, "WhiteBalanced", false, ...
    "ColorTransformed", false, "BlackLevelApplied", true, ...
    "NormalizationDenominator", "linearity_limit_minus_black_level");
result.Statistics = statistics;
result.Outputs = struct( ...
    "MosaicFile", "bayer_mosaic.raw16le", ...
    "MosaicSHA256", fileSHA256(mosaicFile), ...
    "LinearSensorFile", "linear_sensor.mat", ...
    "LinearSensorSHA256", fileSHA256(linearFile));
hashPayload = result;
hashPayload.Outputs = rmfield(hashPayload.Outputs, "LinearSensorSHA256");
if isfield(hashPayload.LibRaw, "probe_architecture")
    hashPayload.LibRaw = rmfield(hashPayload.LibRaw, "probe_architecture");
end
result.ContentSHA256 = camera41exp.integrity.sha256Text( ...
    camera41exp.integrity.canonicalJSON(hashPayload));
resultFile = fullfile(resultFolder, "raw_decode_result.json");
writeText(resultFile, string(jsonencode(result, PrettyPrint=true)) + newline);
result.ResultFolder = string(resultFolder);
result.ResultFile = string(resultFile);
clear resultCleanup

fprintf("Camera-41 RAW decode: VALID\n");
fprintf("  Source: %s\n", rawFile);
fprintf("  CFA: %s, %d x %d visible sensels\n", ...
    metadata.cfa_visible_2x2, metadata.visible_width, metadata.visible_height);
fprintf("  LibRaw: %s\n", metadata.libraw_version);
fprintf("  Content SHA-256: %s\n", result.ContentSHA256);
end

function [statistics, linearMosaic] = sensorStatistics(visible, black, linearity)
linearMosaic = zeros(size(visible), "single");
names = ["R", "G1", "G2", "B"];
positions = [1 1; 1 2; 2 1; 2 2];
channels = repmat(struct("Channel", "", "BlackLevel", 0, ...
    "LinearityLimit", 0, "MinimumRaw", 0, "MaximumRaw", 0, ...
    "MeanLinear", 0, "ClippedFraction", 0, ...
    "HighSignalModeRaw", 0, "HighSignalModeFraction", 0), 4, 1);
for index = 1:4
    row = positions(index, 1); column = positions(index, 2);
    raw = double(visible(row:2:end, column:2:end));
    denominator = linearity(index) - black(index);
    if denominator <= 0
        error("Camera41:Raw:InvalidLevels", ...
            "Linearity limit must exceed black level for every CFA channel.");
    end
    linear = max(0, raw - black(index)) ./ denominator;
    linearMosaic(row:2:end, column:2:end) = single(linear);
    channels(index).Channel = names(index);
    channels(index).BlackLevel = black(index);
    channels(index).LinearityLimit = linearity(index);
    channels(index).MinimumRaw = min(raw, [], "all");
    channels(index).MaximumRaw = max(raw, [], "all");
    channels(index).MeanLinear = mean(linear, "all");
    channels(index).ClippedFraction = mean(raw >= linearity(index), "all");
    highSignal = raw(raw >= linearity(index));
    if ~isempty(highSignal)
        channels(index).HighSignalModeRaw = mode(highSignal);
        channels(index).HighSignalModeFraction = mean( ...
            highSignal == channels(index).HighSignalModeRaw);
    end
end
statistics = struct("Channels", channels, ...
    "AnyClippedFraction", mean(linearMosaic >= 1, "all"));
end

function validateMetadata(value)
required = ["schema", "libraw_version", "probe_architecture", ...
    "make", "model", "body_serial", "internal_body_serial", ...
    "lens_make", "lens_model", "lens_serial", "internal_lens_serial", ...
    "raw_count", "raw_width", "raw_height", ...
    "visible_width", "visible_height", "left_margin", "top_margin", ...
    "raw_pitch_bytes", "colors", "cfa_visible_2x2", "black_level", ...
    "black_level_channels", "white_level", "data_maximum", ...
    "linearity_limits", "iso", "shutter_seconds", "aperture", ...
    "focal_length_mm", "timestamp_unix", "sample_type", "sample_count"];
if ~isstruct(value) || ~all(isfield(value, required)) || ...
        ~isscalar(value) || string(value.schema) ~= "camera41.libraw-probe.v0.2"
    invalidMetadata();
end
textFields = ["make", "model", "body_serial", "internal_body_serial", ...
    "lens_make", "lens_model", "lens_serial", "internal_lens_serial"];
for field = textFields
    if ~ischar(value.(field)) && ~isstring(value.(field))
        invalidMetadata();
    end
end
integerFields = ["raw_count", "raw_width", "raw_height", "visible_width", ...
    "visible_height", "left_margin", "top_margin", "raw_pitch_bytes", ...
    "colors", "sample_count"];
for field = integerFields
    item = value.(field);
    if ~isnumeric(item) || ~isscalar(item) || ~isfinite(item) || item ~= fix(item)
        invalidMetadata();
    end
end
if value.raw_width < 2 || value.raw_height < 2 || ...
        value.raw_width > 100000 || value.raw_height > 100000 || ...
        value.visible_width < 2 || value.visible_height < 2 || ...
        value.left_margin < 0 || value.top_margin < 0 || ...
        value.raw_count < 1 || value.colors < 1 || ...
        value.raw_pitch_bytes < 2 * value.raw_width || ...
        value.left_margin + value.visible_width > value.raw_width || ...
        value.top_margin + value.visible_height > value.raw_height || ...
        value.sample_count ~= value.raw_width * value.raw_height || ...
        value.sample_count > 250000000
    invalidMetadata();
end
if string(value.sample_type) ~= "uint16_le" || ...
        ~isnumeric(value.black_level_channels) || ...
        ~isnumeric(value.linearity_limits) || ...
        numel(value.black_level_channels) ~= 4 || ...
        numel(value.linearity_limits) ~= 4 || ...
        any(~isfinite(value.black_level_channels), "all") || ...
        any(~isfinite(value.linearity_limits), "all") || ...
        ~isnumeric(value.white_level) || ~isscalar(value.white_level) || ...
        ~isfinite(value.white_level) || ...
        value.white_level <= max(value.black_level_channels, [], "all")
    invalidMetadata();
end
end

function invalidMetadata()
error("Camera41:Raw:MetadataInvalid", ...
    "LibRaw probe returned incomplete, inconsistent or incompatible metadata.");
end

function value = fileRecord(path)
info = dir(path);
value = struct("FileName", string(info.name), "SizeBytes", info.bytes, ...
    "SHA256", fileSHA256(path));
end

function digest = fileSHA256(filename)
md = java.security.MessageDigest.getInstance("SHA-256");
bytesIn = java.nio.file.Files.readAllBytes( ...
    java.nio.file.Paths.get(char(filename), javaArray("java.lang.String", 0)));
md.update(bytesIn);
bytes = typecast(md.digest(), "uint8");
digest = lower(join(compose("%02x", bytes), ""));
end

function writeText(filename, content)
[fid, message] = fopen(filename, "w", "n", "UTF-8");
if fid < 0, error("Camera41:Raw:WriteFailed", "%s", message); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", content);
end

function value = canonicalPath(path)
value = string(char(java.io.File(char(path)).getCanonicalPath()));
end

function cleanupFailedResult(folder)
if isfolder(folder) && ~isfile(fullfile(folder, "raw_decode_result.json"))
    rmdir(folder, "s");
end
end
