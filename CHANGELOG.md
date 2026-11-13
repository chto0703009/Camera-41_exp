# Camera-41_exp v1.0.1

- Show the app icon, the purpose of the app and the steps expected of the user when the window opens.
- Mark channels with a median more than 8 EV below the clipping reference as LOW. A dark frame no longer passes with a manual area.
- Ask for a review when a series is inconsistent: clipping at a shorter time than a passing one, or low signal at a longer time.
- Use LibRaw's white level where a RAW has no per-channel linearity limits, and say so in the results.
- Add an application menu with Quit, Copy, Paste and Select All. Quitting waits for a running RAW operation.
- Accept camera RAW files only, with a clear message for JPEG, TIFF and other files.
- Read typed area coordinates correctly where the system groups thousands, as in "1 311".
- Add Python tests, and `tools/build_dmg.py` for the disk image. The source release script no longer requires v0.1.4.
- Keep `--startup-check` and `--smoke-test` out of the diagnostic log.

- Reject malformed measurement coordinates and withhold shutter suggestions when the series is inconsistent.
- Check that each packaged app was built from the current application source.

---

# Camera-41_exp v1.0.0

- Introduce the standalone English Python app for macOS, with separate Apple Silicon and Intel builds.
- Show camera-style shutter times in 1/3 EV steps, with labelled RAW signal and clipping headroom charts.
- Handle shutter metadata rounding at the one-stop boundary for the proportionality check.
- Update installation instructions, handbooks and quick guides. See the [release notes](RELEASE_NOTES.md) for the Gold 200 validation.

---

# Camera-41_exp v0.1.4 - 2026-10-27

- Choose LibRaw for the physical ARM/Intel Mac CPU, including when MATLAB runs under Rosetta.
- Inspect actual Mach-O slices before accepting named readers or unsuffixed fallbacks; reject a foreign-only fallback.
- Execute RAW decoding without shell interpolation; require matching dependencies during local rebuilds.
- Include private Python preparation and transfer-permission repair from the portable-startup work.
- Update Swedish and English handbooks, summaries and installation instructions to v0.1.4.

Validation: ARM LibRaw 0.22.1 startup, both architecture-selection cases, fallback rejection and full EXP release regressions. Physical Intel execution is not newly qualified. Original RAW files and exposure calculations are preserved. EXP has no ExifTool dependency.

# Camera-41_exp v0.1.3

- Use English throughout the app, warnings, result tables, charts and Python/LibRaw preparation dialogs.
- Ship the unified isolated Python 3.13.6 environment setup and native architecture checks.
- Preserve the existing exposure calculations and original RAW files.

Private measurements and local virtual environments are excluded. Existing scientific acceptance is unchanged.

# v0.1.2 — Camera-41_exp

Renamed the application, MATLAB namespace, entry point, documentation, release package and GitHub repository from Camera-41_det to Camera-41_exp. Exposure calculations and report schemas are unchanged.

# v0.1.1

Renamed the application to Camera-41_exp, including the MATLAB package, launcher, documentation and distribution files.

# Changelog

## v0.1.1 - 2026-10-19

First release of the standalone MATLAB tool for choosing digital-camera exposure when scanning negative film at a fixed selected aperture.

- Original Bayer RAW signal/headroom comparison in R, G1, G2 and B, with PASS/REVIEW/FAIL explanations.
- Measured shutter-time candidates and proportionality/bracket review.
- Central automatic region with edge margin, structure warnings and adjustable yellow overlay.
- RAW previews, multi-file selection, remembered folder and focus restoration after dialogs.
- Complete local timestamped diagnostic log with per-RAW timing and error reports.
- Independent operation; no PRE/NEG JSON export or program dependency.
- Swedish and English v0.1.1 handbooks with author, email and GitHub footer links.
- GPL-3.0-or-later notice and bundled third-party licence files.

Verified on MATLAB R2025b/macOS Apple Silicon. Intel reader build information checked under Rosetta; physical Intel operation is unverified. This release does not measure dark-pair noise or create production qualification. Those measurements belong to the current-film workflow in PRE, if used.

## Portable startup included in v0.1.4

- Prepare/sync/rebuild can obtain private CPython 3.13.6 on macOS without requiring an existing exact-version installation. The preparation tool is pinned and checksum verified; native ARM is preferred on Apple Silicon. Identify/check remain read-only.
- Restore the bundled RAW reader's execute bit after transfers before offering a source rebuild; report the original startup failure and explain the complete-folder requirement.
