# SPDX-License-Identifier: GPL-3.0-or-later
"""Film base + fog exposure measurements on undemosaiced RGGB data."""

from dataclasses import dataclass
from functools import cache
from hashlib import file_digest
import json
import math
from pathlib import Path
import platform
import subprocess
import sys
from tempfile import TemporaryDirectory

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CHANNELS = ("R", "G1", "G2", "B")
POSITIONS = ((0, 0), (0, 1), (1, 0), (1, 1))
RAW_EXTENSIONS = ("cr2", "cr3", "nef", "arw", "dng", "raf", "rw2", "orf", "pef")
PASS_MARGIN = 1 / 3
FAIL_FRACTION = 1e-4
# A channel median more than 8 EV below the clipping reference is not a usable
# film base + fog exposure (dark frame, lens cap or wrong file).
MIN_SIGNAL = 2**-8


class AreaReview(ValueError):
    def __init__(self, path, roi, reasons):
        self.path = path
        self.roi = roi
        super().__init__(f"{path.name}: {' '.join(reasons)} Adjust the yellow measurement area.")


@dataclass
class Capture:
    path: Path
    sha256: str
    body: tuple
    iso: float
    aperture: float
    seconds: float
    linear: np.ndarray
    code_range: np.ndarray
    white_level_fallback: bool = False


@dataclass
class Reading:
    path: str
    sha256: str
    seconds: float
    status: str
    signal: list
    margin: list
    clipped: list
    channel_status: list
    white_level_fallback: bool = False


@dataclass
class Selection:
    status: str = "NO_PASSING_EXPOSURE"
    candidate: float | None = None
    next_test: float | None = None
    proportionality: str = "INSUFFICIENT_PASSING_TIMES"
    deviation: list | None = None


@cache
def raw_probe():
    test = subprocess.run(
        ["/usr/sbin/sysctl", "-n", "hw.optional.arm64"], capture_output=True, text=True
    )
    cpu = "arm64" if test.stdout.strip() == "1" else "x86_64"
    if getattr(sys, "frozen", False):
        cpu = platform.machine()
    base = ROOT / "tools/bin/camera41_raw_probe"
    for path in (base.with_name(f"{base.name}_{cpu}"), base):
        if path.is_file():
            slices = subprocess.run(["/usr/bin/file", "-b", str(path.resolve())],
                                    capture_output=True, text=True, check=True).stdout
            if "Mach-O" in slices and cpu in slices:
                return ("/usr/bin/arch", f"-{cpu}", str(path))
    raise FileNotFoundError(f"Camera-41_exp requires a {cpu} LibRaw probe in {base.parent}.")


def source_record(path):
    with path.open("rb") as stream:
        info = path.stat()
        return info.st_size, info.st_mtime_ns, file_digest(stream, "sha256").hexdigest()


def is_raw(path):
    return Path(path).suffix[1:].lower() in RAW_EXTENSIONS


def decode(path):
    path = Path(path).resolve(strict=True)
    if not is_raw(path):
        raise ValueError(f"{path.name} is not a camera RAW file. Use the original RAW capture "
                         f"({', '.join(RAW_EXTENSIONS).upper()}), not a JPEG, TIFF or other export.")
    before = source_record(path)
    with TemporaryDirectory(prefix="camera41-exp-") as folder:
        metadata = Path(folder) / "metadata.json"
        mosaic = Path(folder) / "mosaic.raw"
        result = subprocess.run(
            [*raw_probe(), str(path), str(metadata), str(mosaic)],
            capture_output=True, text=True, errors="replace", timeout=300,
        )
        if result.returncode:
            raise ValueError(f"{path.name}: LibRaw failed ({result.returncode}). {result.stderr.strip()}")
        data = json.loads(metadata.read_text(encoding="utf-8"))
        if data.get("schema") != "camera41.libraw-probe.v0.2" or data.get("sample_type") != "uint16_le":
            raise ValueError("Incompatible LibRaw probe metadata.")
        if data["cfa_visible_2x2"] != "RGGB":
            raise ValueError(f"{path.name}: this analysis requires an RGGB Bayer sensor. "
                             f"This RAW has the pattern {data['cfa_visible_2x2']}.")
        rw, rh = data["raw_width"], data["raw_height"]
        w, h = data["visible_width"], data["visible_height"]
        x, y = data["left_margin"], data["top_margin"]
        dimensions = (rw, rh, w, h, x, y, data["sample_count"])
        if (not all(type(n) is int for n in dimensions)
                or not (2 <= w <= rw <= 100000 and 2 <= h <= rh <= 100000)
                or min(x, y) < 0 or x + w > rw or y + h > rh
                or rw * rh != data["sample_count"] or rw * rh > 250_000_000
                or mosaic.stat().st_size != 2 * rw * rh):
            raise ValueError("Invalid LibRaw mosaic dimensions.")
        raw = np.fromfile(mosaic, dtype="<u2").reshape(rh, rw)[y:y+h, x:x+w]
    if before != source_record(path):
        raise ValueError(f"{path.name}: RAW source changed during decoding.")
    black = np.asarray(data["black_level_channels"], dtype=float)
    limit = np.asarray(data["linearity_limits"], dtype=float)
    if black.shape != (4,) or limit.shape != (4,):
        raise ValueError("Expected four LibRaw channel levels.")
    # LibRaw reports per-channel linearity limits for some cameras only.
    # Where they are absent, use its white level as the clipping reference.
    fallback = bool(np.any(limit <= 0))
    if fallback:
        white = data.get("white_level")
        if not isinstance(white, (int, float)) or not math.isfinite(white) or white <= 0:
            raise ValueError(f"{path.name}: the RAW has no linearity limit or white level.")
        limit = np.where(limit > 0, limit, float(white))
    order = [0, 1, 3, 2]
    black, limit = black[order], limit[order]
    code_range = limit - black
    if not np.all(np.isfinite(code_range) & (code_range > 0)):
        raise ValueError(f"{path.name}: the clipping reference must exceed the black level.")
    iso, aperture, seconds = (data[key] for key in ("iso", "aperture", "shutter_seconds"))
    if not all(math.isfinite(n) and n > 0 for n in (iso, aperture, seconds)):
        raise ValueError(f"{path.name}: RAW exposure metadata is missing or invalid.")
    linear = np.empty(raw.shape, dtype=np.float32)
    for i, (r, c) in enumerate(POSITIONS):
        plane = raw[r::2, c::2].astype(float)
        linear[r::2, c::2] = np.maximum(plane - black[i], 0) / code_range[i]
    body = tuple(data[key] for key in ("make", "model", "body_serial", "internal_body_serial"))
    return Capture(path, before[2], body, iso, aperture, seconds, linear, code_range, fallback)


def automatic_area(mosaic):
    h, w = mosaic.shape
    if min(w, h) < 40:
        raise ValueError("RAW image is too small for automatic area selection.")
    x, y = int(.15 * w), int(.15 * h)
    roi = (x + 1, y + 1, w - 2*x, h - 2*y)
    region = mosaic[y:h-y, x:w-x]
    xx, yy = np.meshgrid(np.linspace(-1, 1, 12), np.linspace(-1, 1, 12))
    design = np.column_stack([a.ravel() for a in (np.ones_like(xx), xx, yy, xx**2, xx*yy, yy**2)])
    low_signal = uneven = wide_range = False
    for r, c in POSITIONS:
        plane = region[r::2, c::2].astype(float)
        if np.median(plane) <= 1e-5:
            low_signal = True
            continue
        y_edges, x_edges = (np.floor(np.linspace(0, size, 13) + .5).astype(int) for size in plane.shape)
        tiles = [
            np.median(plane[a:b, d:e])
            for a, b in zip(y_edges[:-1], y_edges[1:])
            for d, e in zip(x_edges[:-1], x_edges[1:])
        ]
        stops = np.log2(np.maximum(tiles, 1e-8))
        fit = design @ np.linalg.lstsq(design, stops, rcond=None)[0]
        uneven |= np.percentile(np.abs(stops - fit), 95, method="hazen") > .18
        lo, hi = np.percentile(stops, [5, 95], method="hazen")
        wide_range |= hi - lo > 1
    reasons = []
    if low_signal:
        reasons.append("The signal is too low to assess a uniform film base + fog area.")
    if uneven:
        reasons.append("Structure or unevenness differs from uniform blank film base + fog.")
    if wide_range:
        reasons.append("Brightness variation in the proposed area exceeds 1 EV.")
    return roi, reasons


def measure(capture, roi):
    x, y, w, h = roi
    height, width = capture.linear.shape
    if min(w, h) < 20 or min(x, y) < 1 or x + w - 1 > width or y + h - 1 > height:
        raise ValueError(f"Use an area of at least 20 × 20 inside the {width} × {height} sensor.")
    signal, margin, clipped, statuses = [], [], [], []
    for i, (r, c) in enumerate(POSITIONS):
        start_y = y - 1 + (r - (y - 1)) % 2
        start_x = x - 1 + (c - (x - 1)) % 2
        values = capture.linear[start_y:y-1+h:2, start_x:x-1+w:2].astype(float)
        # Headroom is reported down to one sensor code above black.
        peak = max(np.percentile(values, 99.9, method="hazen"), 1 / capture.code_range[i])
        ev = -math.log2(peak)
        fraction = float(np.mean(values >= 1))
        median = float(np.median(values))
        signal.append(median * capture.code_range[i])
        margin.append(ev)
        clipped.append(fraction)
        statuses.append("FAIL" if fraction >= FAIL_FRACTION else "REVIEW" if ev < PASS_MARGIN
                        else "LOW" if median < MIN_SIGNAL else "PASS")
    status = "FAIL" if "FAIL" in statuses else "PASS" if set(statuses) == {"PASS"} else "REVIEW"
    return Reading(str(capture.path), capture.sha256, capture.seconds, status, signal, margin,
                   clipped, statuses, capture.white_level_fallback)


def select_exposure(readings):
    result = Selection()
    times = sorted({row.seconds for row in readings})
    passed = {}
    for seconds in times:
        group = [row for row in readings if row.seconds == seconds]
        if all(row.status == "PASS" for row in group):
            passed[seconds] = np.median([row.signal for row in group], axis=0) / seconds
    accepted = [row.seconds for row in readings if row.status == "PASS"]
    if not accepted:
        return result
    # Headroom must shrink and signal must grow with shutter time. A series
    # that breaks this order was not captured under constant conditions.
    near_limit = {row.seconds for row in readings if {"REVIEW", "FAIL"} & set(row.channel_status)}
    low = {row.seconds for row in readings if "LOW" in row.channel_status}
    shortest_pass, longest_pass = min(accepted), max(accepted)
    if any(t <= longest_pass for t in near_limit) or any(t >= shortest_pass for t in low):
        return Selection(status="REVIEW_INCONSISTENT_SERIES")
    best = result.candidate = max(passed)
    upper = next((t for t in times if t > best and t in near_limit), None)
    if upper is None:
        result.status = "PROVISIONAL_ADD_HIGHER_EXPOSURE"
        result.next_test = best * 2**PASS_MARGIN
    elif math.log2(upper / best) > PASS_MARGIN + 1e-9:
        result.status = "PROVISIONAL_REFINE_BRACKET"
        result.next_test = math.sqrt(best * upper)
    else:
        result.status = "HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY"
    # LibRaw exposes shutter times with float32 precision. Allow its rounding
    # at the exact one-stop boundary without accepting a narrower bracket.
    span = best / min(passed)
    if len(passed) >= 3 and (span >= 2 or math.isclose(span, 2, rel_tol=1e-7)):
        slopes = np.array(list(passed.values()))
        reference = np.median(slopes, axis=0)
        if np.any(reference <= 0):
            result.proportionality = "REVIEW_NONPOSITIVE_SIGNAL"
        else:
            deviation = np.max(np.abs(slopes / reference - 1), axis=0)
            result.deviation = deviation.tolist()
            result.proportionality = (
                "PROPORTIONALITY_CHECK_PASS" if np.all(deviation <= .05)
                else "REVIEW_NONPROPORTIONAL_RESPONSE"
            )
        if result.proportionality.startswith("REVIEW"):
            result.status = "REVIEW_LINEAR_RESPONSE_BEFORE_USING_CANDIDATE"
    return result


def analyse(paths, roi=None):
    paths = [Path(path).resolve(strict=True) for path in paths]
    if not paths or len(paths) != len(set(paths)):
        raise ValueError("Supply distinct existing film base + fog RAW files.")
    automatic = roi is None
    readings = []
    settings = None
    for path in paths:
        capture = decode(path)
        current = (capture.body, capture.iso, capture.linear.shape)
        if settings is None:
            settings, aperture = current, capture.aperture
        if current != settings or abs(aperture - capture.aperture) >= 1e-12:
            raise ValueError("All RAWs must use the same camera, ISO, aperture and image dimensions.")
        if automatic:
            proposed, reasons = automatic_area(capture.linear)
            if reasons:
                raise AreaReview(path, proposed, reasons)
            if roi is None:
                roi = proposed
        readings.append(measure(capture, roi))
        del capture
    readings.sort(key=lambda row: row.seconds)
    return roi, readings, select_exposure(readings)
