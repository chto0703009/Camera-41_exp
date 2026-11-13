# Camera-41_exp v1.0.1

Camera-41_exp helps set the digital camera exposure when digitising C-41 colour and black-and-white (B&W) film negatives with a VALOI setup. At a fixed aperture, it compares RAW captures of clear film base plus fog to find a shutter speed that gives a strong signal with room before clipping. Too much exposure can clip a sensor channel. Too little leaves a weak signal, making noise more visible when the scan is brightened.

[English summary and installation (PDF)](output/pdf/Camera41_exp_Summary_EN.pdf)

## Run the Python app on macOS

Open the standalone `Camera-41_exp.app` built for your Mac (Apple Silicon or Intel). See [installation](INSTALL.md) and [release notes](RELEASE_NOTES.md).
It includes Python, the native AppKit interface and the LibRaw probe and runs
without MATLAB. The locally built app is ad hoc signed.

To run from source with Python 3.13:

```sh
python3.13 -m venv .venv
.venv/bin/python -m pip install -r requirements-app.txt
.venv/bin/python -m camera41exp.app
```

You can then double-click `Start Camera-41_exp.command`. Select RAW files from
the file picker, preview one and drag to set a manual measurement area if
needed. Results show the four Bayer channels, the bracket recommendation and
the next step in PRE. The **Exposure comparison** tab plots signal and clipping
headroom against shutter time in 1/3 EV steps. The dashed line marks the
minimum headroom of 1/3 EV for PASS.

To build a standalone app, install `pyinstaller==6.22.3` into the same
environment and run `.venv/bin/python tools/build_exp_python_app.py`. See [installation](INSTALL.md#run-or-build-from-source) for the Intel build dependencies. The app is created under
`local-config/python-app/<architecture>/dist/`. Its executable accepts
`--startup-check` and `--smoke-test /path/to/test.CR2`.

The PDF handbooks describe the English Python interface.

Run the Python tests with `.venv/bin/python -m unittest discover -s tests`. They cover the
measurements, exposure selection and RAW decoding without needing RAW files.
After building both apps, `.venv/bin/python tools/build_dmg.py --libraw-source LibRaw-0.22.1.tar.gz LibRaw-0.22.3.tar.gz --smoke-raw /path/to/series/*.CR2` audits them and
creates the release disk image under `dist/`.

Add blank film base + fog RAWs at different shutter times, document the light/sample and analyse. The app selects an edge-safe central area, checks for unexpected structure and compares RAW signal and clipping margin. A yellow region is shown for inspection or adjustment when needed. Choose a measured passing time in the list.

Camera-41_exp does not export a JSON handoff. At the chosen time, capture the current film's empty FB+F frame and two independent dark RAWs with the same camera, ISO, shutter and aperture. Load these in PRE tab 7 for signal/noise measurement. PRE includes those measured results in the film characterisation for NEG.

The last RAW folder is remembered. **Open log** opens the Python app's
diagnostic log, including file choices, analyses and errors. The standalone
app stores it in `~/Library/Logs/Camera-41_exp/camera41_exp.jsonl`. Source runs
store it in `logs/camera41_exp.jsonl`.

A capture passes when every channel keeps at least 1/3 EV of headroom, has fewer than 0.01% of its values at the clipping reference and a median within 8 EV of it. Darker channels are marked LOW, so a dark frame cannot pass. The app asks for a review when the series is inconsistent, for example when a shorter time clips while a longer one passes.

The analysis needs an RGGB Bayer sensor. It is validated with Canon CR2 files. For RAWs without per-channel linearity limits, LibRaw's white level is the clipping reference, and the results say so. Other makes are untested.

Both interfaces use the bundled LibRaw probe. Original RAWs are unchanged. Automatic uniformity screening is heuristic and does not establish physical film identity or production qualification. GPL-3.0-or-later; see LICENSE and third_party/licenses.

## Handbooks / Handböcker

- [English handbook (PDF)](output/pdf/Camera41_exp_Handbook_EN.pdf)
- [Svensk handbok (PDF)](output/pdf/Camera41_exp_Handbook_SV.pdf)
The following work instructions cover the wider Camera-41 workflow and refer to the earlier MATLAB interface. Use the v1.0.1 handbooks above for current installation and controls.

- [Arbetsinstruktion för digitaliseringsexponering (PDF, svenska)](output/pdf/Camera41_EXP_Digitaliseringsexponering_SV.pdf) — FB+F-serie, exponeringsval och överlämning till Camera-41_pre.
- [Digitisation exposure work instruction (PDF, English)](output/pdf/Camera41_EXP_Digitisation_Exposure_EN.pdf)

Editable sources are in `docs/handbook/handbook_sv.json` and `handbook_en.json`. Rebuild both PDFs with `python tools/build_handbooks.py` (requires reportlab). The handbooks describe why FB+F exposure is used to avoid clipping, capture setup, automatic/manual areas, results, standalone operation and logging.

[Sammanfattning på svenska (PDF)](output/pdf/Camera41_exp_Sammanfattning_SV.pdf) — svensk ensidesguide för v1.0.1.

## Legacy MATLAB Python environment

The MATLAB version checks a local Python 3.13.6 environment with the shared Camera-41, InkProf and SpectraLab package versions. See [PYTHON_ENVIRONMENT.md](PYTHON_ENVIRONMENT.md) for setup and maintenance.

### Native macOS RAW support

Source runs select LibRaw for the physical Mac CPU. A standalone app
includes the LibRaw probe built for its labelled architecture. Both the architecture-suffixed executable and the unsuffixed fallback
are checked for a matching Mach-O slice. A filename alone is not sufficient;
a foreign-only fallback is rejected. Legacy saved architecture preferences do
not override automatic hardware detection. Both ARM and Intel executables remain
included. Local rebuilds require matching LibRaw and libomp libraries and compile
explicitly for the selected architecture.

External tools run with separate process arguments. Native universal binaries
are pinned to the physical architecture. Perl scripts such as ExifTool use a
matching Perl interpreter (including system arm64e slices). In DC, embedded-preview
extraction uses the same native-interpreter policy; EXP needs no ExifTool.
