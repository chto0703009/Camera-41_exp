# Camera-41_exp v0.1.3 - installation

This is a MATLAB application, not a standalone macOS executable. PRE and NEG are not required.

1. Download and extract `Camera-41_exp-v0.1.3-macos.zip` to a local writable folder.
2. Open MATLAB. Open `start.m` from the extracted folder and press **Run**.
3. Alternatively, set MATLAB's current folder to the extracted folder and run `startCamera41_exp;`.
4. Read the Swedish or English handbook under `output/pdf/`.

## Requirements and verification

- Tested: MATLAB R2025b on macOS with Apple Silicon.
- Image Processing Toolbox is needed for region editing with `drawrectangle`. In the tested MATLAB release, `imshow` and `prctile` are available in MATLAB itself.
- The bundled native LibRaw reader is selected for the physical Mac architecture.
- Apple Silicon: application startup, regression tests and a real RAW analysis are verified.
- Intel: a reader and its native libraries are included; the reader's build information was checked under Rosetta. Physical Intel MATLAB/UI/RAW operation has not been verified.
- Windows, Linux and older MATLAB releases have not been qualified for this release.
- The application verifies its own isolated Python 3.13.6 environment at startup. Use setup_python_environment("check"), "sync" or "rebuild" to maintain it; see PYTHON_ENVIRONMENT.md.

No Homebrew installation is required for the supplied reader on the verified computer. If macOS blocks a downloaded native executable, inspect the security prompt and the local log rather than disabling system security globally. Do not move only `start.m`: keep `src`, `tools`, `VERSION` and the other supplied files together.

The application creates `logs/camera41_exp.jsonl` inside its folder. Choose **Log > Open complete log** for diagnostics. The most recent RAW folder is stored in MATLAB preferences. Close the app window before replacing/updating program files.

## Data and scope

Use original Bayer RAWs of empty film base + fog at fixed camera/ISO/aperture/light, changing only shutter time. No photographs are included in the download. The app does not modify input RAWs, export a PRE/NEG handoff, control the camera or establish a complete production qualification. Its automatic area check is a heuristic.

At the selected time, take the current film's FB+F capture and two matched dark captures, then import those directly into PRE if that workflow is used. Camera-41_exp remains independently usable.

## Integrity and licences

`SHA256SUMS.txt` covers the downloadable ZIP and the separate handbook PDFs. `RELEASE_MANIFEST.json` inside the ZIP records the source commit and per-file SHA-256 digests. Compare checksums with your SHA-256 tool (on macOS: `shasum -a 256 filename`).

The project's code/documentation are GPL-3.0-or-later. Read `LICENSE`, `LICENSE_NOTICE.md` and `third_party/licenses`. MATLAB has a separate licence.

Christer Törnkvist - christer@borgasundsfotografiska.se
https://github.com/chto0703009/Camera-41_exp
