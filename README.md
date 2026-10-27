# Camera-41_exp v0.1.4

[English summary and installation (PDF)](output/pdf/Camera41_exp_Summary_EN.pdf)

For download/setup requirements, see [INSTALL.md](INSTALL.md) and [CHANGELOG.md](CHANGELOG.md).

Open `start.m` in MATLAB and press Run, or call `startCamera41_exp` from this folder.

This app helps choose the digital-camera shutter time at a fixed selected aperture. Add blank film base + fog RAWs at different shutter times, document the light/sample and analyse. The app selects an edge-safe central area, checks for unexpected structure and compares RAW signal and clipping margin. A yellow region is shown for inspection or adjustment when needed. Choose a measured passing time in the list.

Camera-41_exp does not export a JSON handoff. At the chosen time, capture the current film's empty FB+F frame and two independent dark RAWs with the same camera, ISO, shutter and aperture. Load these in PRE tab 7 for signal/noise measurement. PRE includes those measured results in the film characterisation for NEG.

The last RAW folder is remembered. The local application log is `logs/camera41_exp.jsonl`, available from **Log → Open complete log**. It includes timing, file choices, analyses and errors. Native dialog timing includes the user's file selection time. Logs are excluded from Git.

MATLAB and the bundled LibRaw probe are required. Original RAWs are unchanged. Automatic uniformity screening is heuristic and does not establish physical film identity or production qualification. GPL-3.0-or-later; see LICENSE and third_party/licenses.

## Handbooks / Handböcker

- [English handbook (PDF)](output/pdf/Camera41_exp_Handbook_EN.pdf)
- [Svensk handbok (PDF)](output/pdf/Camera41_exp_Handbook_SV.pdf)

Editable sources are in `docs/handbook/handbook_sv.json` and `handbook_en.json`. Rebuild both PDFs with `python tools/build_handbooks.py` (requires reportlab). The handbooks describe why FB+F exposure is used to avoid clipping, capture setup, automatic/manual areas, results, standalone operation and logging.

[Sammanfattning på svenska (PDF)](output/pdf/Camera41_exp_Sammanfattning_SV.pdf) - fristående ensidesguide för v0.1.4.

## Pythonmiljö och datorbyte

Programmet använder en egen `.venv` med Python 3.13.6 och samma fullständiga paketversioner som övriga aktiva Camera-41-, InkProf- och SpectraLab-program. Se [PYTHON_ENVIRONMENT.md](PYTHON_ENVIRONMENT.md) för installation, kontroll och säker ombyggnad.

### Native macOS RAW support

LibRaw selection follows the physical Mac CPU, including when MATLAB runs under
Rosetta. Both the architecture-suffixed executable and the unsuffixed fallback
are checked for a matching Mach-O slice. A filename alone is not sufficient;
a foreign-only fallback is rejected. Legacy saved architecture preferences do
not override automatic hardware detection. Both ARM and Intel executables remain
included. Local rebuilds require matching LibRaw and libomp libraries and compile
explicitly for the selected architecture.

External tools run with separate process arguments. Native universal binaries
are pinned to the physical architecture. Perl scripts such as ExifTool use a
matching Perl interpreter (including system arm64e slices). In DC, embedded-preview
extraction uses the same native-interpreter policy; EXP needs no ExifTool.
