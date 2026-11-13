# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests for the Python exposure measurements.

Run from the checkout with: .venv/bin/python -m unittest discover -s tests
"""

import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest import mock

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from camera41exp import exposure  # noqa: E402
from camera41exp.exposure import (  # noqa: E402
    AreaReview, Capture, Reading, automatic_area, measure, select_exposure,
)

CODE_RANGE = np.full(4, 14000.0)
ROI = (1, 1, 600, 400)

# Stands in for the LibRaw probe: copies prepared metadata and mosaic files.
FAKE_PROBE = """
import shutil, sys
source, metadata, mosaic = sys.argv[1:]
shutil.copy(source + ".json", metadata)
shutil.copy(source + ".bin", mosaic)
"""


def capture(level, seconds=1.0):
    linear = np.full((400, 600), level, dtype=np.float32)
    return Capture(Path(f"frame_{seconds}.CR2"), "0", ("a",) * 4, 100, 8, seconds, linear, CODE_RANGE)


def reading(seconds, status, signal=None, channel_status=None):
    return Reading(f"{seconds}.CR2", "0", seconds, status,
                   signal or [100 * seconds, 80 * seconds, 70 * seconds, 60 * seconds],
                   [1.0] * 4, [0.0] * 4, channel_status or [status] * 4)


class MeasureTests(unittest.TestCase):
    def test_pass_review_fail(self):
        self.assertEqual(measure(capture(0.5), ROI).status, "PASS")
        self.assertEqual(measure(capture(0.9), ROI).status, "REVIEW")
        self.assertEqual(measure(capture(1.0), ROI).status, "FAIL")

    def test_signal_and_headroom(self):
        row = measure(capture(0.25), ROI)
        self.assertAlmostEqual(row.signal[0], 3500, places=3)
        self.assertAlmostEqual(row.margin[0], 2, places=6)
        self.assertEqual(row.clipped, [0.0] * 4)

    def test_dark_frame_is_not_a_pass(self):
        row = measure(capture(0), ROI)
        self.assertEqual(row.status, "REVIEW")
        self.assertEqual(row.channel_status, ["LOW"] * 4)
        # Headroom stops at one sensor code above black.
        self.assertAlmostEqual(row.margin[0], np.log2(14000), places=6)

    def test_one_dark_channel_blocks_pass(self):
        frame = capture(0.5)
        frame.linear[1::2, 1::2] = 0.001
        row = measure(frame, ROI)
        self.assertEqual(row.channel_status, ["PASS", "PASS", "PASS", "LOW"])
        self.assertEqual(row.status, "REVIEW")

    def test_small_clipped_fraction_fails(self):
        frame = capture(0.5)
        frame.linear[0:40:2, 0:40:2] = 1.0  # 400 of 60,000 red samples
        row = measure(frame, ROI)
        self.assertEqual(row.channel_status[0], "FAIL")
        self.assertEqual(row.status, "FAIL")

    def test_channels_follow_the_mosaic_for_odd_origins(self):
        frame = capture(0.5)
        frame.linear[0::2, 0::2] = 0.1  # red sites
        row = measure(frame, (2, 2, 300, 200))
        self.assertAlmostEqual(row.signal[0], 1400, places=2)
        self.assertAlmostEqual(row.signal[3], 7000, places=2)

    def test_area_must_fit_the_sensor(self):
        for roi in ((1, 1, 19, 400), (0, 1, 100, 100), (1, 1, 601, 400)):
            with self.assertRaises(ValueError):
                measure(capture(0.5), roi)


class SelectionTests(unittest.TestCase):
    def test_bracketed_candidate(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "PASS"), reading(4, "PASS"),
                                  reading(5, "REVIEW")])
        self.assertEqual(result.candidate, 4)
        self.assertEqual(result.status, "HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY")
        self.assertEqual(result.proportionality, "PROPORTIONALITY_CHECK_PASS")

    def test_missing_upper_bracket(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "PASS"), reading(4, "PASS")])
        self.assertEqual(result.status, "PROVISIONAL_ADD_HIGHER_EXPOSURE")
        self.assertAlmostEqual(result.next_test, 4 * 2 ** (1 / 3))

    def test_every_replicate_must_pass(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "PASS"), reading(4, "PASS"),
                                  reading(4, "FAIL")])
        self.assertEqual(result.status, "REVIEW_INCONSISTENT_SERIES")
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.next_test)

    def test_nonproportional_response(self):
        rows = [reading(1, "PASS"), reading(2, "PASS"),
                reading(4, "PASS", signal=[280, 224, 196, 168]), reading(5, "REVIEW")]
        result = select_exposure(rows)
        self.assertEqual(result.status, "REVIEW_LINEAR_RESPONSE_BEFORE_USING_CANDIDATE")
        self.assertAlmostEqual(max(result.deviation), 0.3)

    def test_one_stop_span_tolerates_float32_shutter_times(self):
        times = [float(np.float32(t)) for t in (1 / 20, 1 / 15, 1 / 10)]
        result = select_exposure([reading(t, "PASS") for t in times])
        self.assertEqual(result.proportionality, "PROPORTIONALITY_CHECK_PASS")

    def test_no_passing_exposure(self):
        result = select_exposure([reading(1, "FAIL"), reading(2, "REVIEW")])
        self.assertIsNone(result.candidate)
        self.assertEqual(result.status, "NO_PASSING_EXPOSURE")

    def test_clipping_at_a_shorter_time_is_inconsistent(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "FAIL"), reading(2.5, "PASS")])
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.next_test)
        self.assertEqual(result.status, "REVIEW_INCONSISTENT_SERIES")

    def test_low_signal_at_a_longer_time_is_inconsistent(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "PASS"),
                                  reading(4, "REVIEW", channel_status=["LOW"] * 4)])
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.next_test)
        self.assertEqual(result.status, "REVIEW_INCONSISTENT_SERIES")

    def test_dark_replicate_of_a_passing_time_is_inconsistent(self):
        result = select_exposure([reading(1, "PASS"), reading(2, "PASS"),
                                  reading(2, "REVIEW", channel_status=["LOW"] * 4), reading(2.5, "REVIEW")])
        self.assertIsNone(result.candidate)
        self.assertIsNone(result.next_test)
        self.assertEqual(result.status, "REVIEW_INCONSISTENT_SERIES")

    def test_low_signal_at_shorter_times_is_expected(self):
        result = select_exposure([reading(1, "REVIEW", channel_status=["PASS", "PASS", "PASS", "LOW"]),
                                  reading(2, "PASS"), reading(2.5, "REVIEW")])
        self.assertEqual(result.candidate, 2)
        self.assertEqual(result.status, "HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY")


class AutomaticAreaTests(unittest.TestCase):
    def test_uniform_area(self):
        roi, reasons = automatic_area(np.full((400, 600), 0.4, dtype=np.float32))
        self.assertEqual(roi, (91, 61, 420, 280))
        self.assertEqual(reasons, [])

    def test_dark_frame(self):
        _, reasons = automatic_area(np.zeros((400, 600), dtype=np.float32))
        self.assertEqual(len(reasons), 1)
        self.assertIn("too low", reasons[0])

    def test_structure(self):
        mosaic = np.full((400, 600), 0.4, dtype=np.float32)
        mosaic[150:250, 200:400] = 0.05
        _, reasons = automatic_area(mosaic)
        self.assertTrue(any("Structure" in reason for reason in reasons))

    def test_small_image(self):
        with self.assertRaises(ValueError):
            automatic_area(np.ones((30, 600), dtype=np.float32))


class DecodeTests(unittest.TestCase):
    """Decoding and analysis against a stand-in for the LibRaw probe."""

    def setUp(self):
        folder = TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name).resolve()
        probe = self.folder / "probe.py"
        probe.write_text(FAKE_PROBE)
        patch = mock.patch.object(exposure, "raw_probe", lambda: (sys.executable, str(probe)))
        patch.start()
        self.addCleanup(patch.stop)

    def raw(self, name, level, seconds, **changes):
        """Write a 64 × 48 sensor with a 60 × 44 visible area filled with one raw value."""
        path = self.folder / name
        path.write_bytes(name.encode())
        metadata = {
            "schema": "camera41.libraw-probe.v0.2", "sample_type": "uint16_le", "cfa_visible_2x2": "RGGB",
            "raw_width": 64, "raw_height": 48, "visible_width": 60, "visible_height": 44,
            "left_margin": 4, "top_margin": 4, "sample_count": 64 * 48,
            "black_level_channels": [2048, 2048, 2048, 2048], "white_level": 16383,
            "linearity_limits": [14048, 14048, 14048, 14048],
            "iso": 100, "aperture": 8, "shutter_seconds": seconds,
            "make": "Test", "model": "Camera", "body_serial": "1", "internal_body_serial": "",
        } | changes
        Path(f"{path}.json").write_text(json.dumps(metadata))
        np.full(64 * 48, level, dtype="<u2").tofile(f"{path}.bin")
        return path

    def test_decode_normalises_to_the_linearity_limit(self):
        frame = exposure.decode(self.raw("a.CR2", 8048, 0.1))
        self.assertEqual(frame.linear.shape, (44, 60))
        self.assertAlmostEqual(float(frame.linear[0, 0]), 0.5)
        self.assertFalse(frame.white_level_fallback)
        self.assertEqual(frame.seconds, 0.1)

    def test_white_level_replaces_missing_linearity_limits(self):
        frame = exposure.decode(self.raw("a.NEF", 16383, 0.1, linearity_limits=[0, 0, 0, 0]))
        self.assertTrue(frame.white_level_fallback)
        self.assertAlmostEqual(float(frame.linear[0, 0]), 1.0)
        np.testing.assert_allclose(frame.code_range, 16383 - 2048)

    def test_input_must_be_a_raw_file(self):
        for name in ("scan.jpg", "scan.tif", "scan"):
            path = self.folder / name
            path.write_bytes(b"x")
            with self.assertRaisesRegex(ValueError, "not a camera RAW file"):
                exposure.decode(path)
            with self.assertRaisesRegex(ValueError, "not a camera RAW file"):
                exposure.analyse([path])
        self.assertTrue(exposure.is_raw("a.cr2") and exposure.is_raw("A.DNG"))

    def test_no_clipping_reference(self):
        with self.assertRaisesRegex(ValueError, "no linearity limit or white level"):
            exposure.decode(self.raw("a.NEF", 100, 0.1, linearity_limits=[0, 0, 0, 0], white_level=0))

    def test_other_mosaic_patterns_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "pattern GRBG"):
            exposure.decode(self.raw("a.ORF", 100, 0.1, cfa_visible_2x2="GRBG"))

    def test_inconsistent_dimensions_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "dimensions"):
            exposure.decode(self.raw("a.CR2", 100, 0.1, sample_count=10))

    def test_analyse_series(self):
        paths = [self.raw(f"{i}.CR2", 2048 + level, seconds)
                 for i, (level, seconds) in enumerate(((2000, 0.1), (4000, 0.2), (8000, 0.4), (11500, 0.575)))]
        roi, rows, selection = exposure.analyse(reversed(paths))
        self.assertEqual(roi, (10, 7, 42, 32))
        self.assertEqual([row.status for row in rows], ["PASS", "PASS", "PASS", "REVIEW"])
        self.assertEqual(selection.candidate, 0.4)
        self.assertEqual(selection.status, "PROVISIONAL_REFINE_BRACKET")
        self.assertEqual(selection.proportionality, "PROPORTIONALITY_CHECK_PASS")

    def test_automatic_area_stops_on_a_dark_frame(self):
        with self.assertRaises(AreaReview):
            exposure.analyse([self.raw("dark.CR2", 2048, 0.1)])

    def test_manual_area_does_not_pass_a_dark_frame(self):
        _, rows, selection = exposure.analyse([self.raw("dark.CR2", 2049, 0.1)], (1, 1, 60, 44))
        self.assertEqual(rows[0].status, "REVIEW")
        self.assertIsNone(selection.candidate)

    def test_settings_must_match(self):
        paths = [self.raw("a.CR2", 6000, 0.1), self.raw("b.CR2", 6000, 0.2, iso=200)]
        with self.assertRaisesRegex(ValueError, "same camera"):
            exposure.analyse(paths)

    def test_duplicates_are_rejected(self):
        path = self.raw("a.CR2", 6000, 0.1)
        with self.assertRaises(ValueError):
            exposure.analyse([path, path])


if __name__ == "__main__":
    unittest.main()
