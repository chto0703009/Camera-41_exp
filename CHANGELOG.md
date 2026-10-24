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
