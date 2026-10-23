# v0.1.1

Renamed the application to Camera-41_det, including the MATLAB package, launcher, documentation and distribution files.

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
