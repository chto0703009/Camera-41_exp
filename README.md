# Camera-41 Exposure v0.1.0

[English summary and installation (PDF)](output/pdf/Camera41_Exposure_Summary_EN.pdf)

For download/setup requirements, see [INSTALL.md](INSTALL.md) and [CHANGELOG.md](CHANGELOG.md).

Open `start.m` in MATLAB and press Run, or call `startCamera41_exposure` from this folder.

This app helps choose the digital-camera shutter time at a fixed selected aperture. Add blank film base + fog RAWs at different shutter times, document the light/sample and analyse. The app selects an edge-safe central area, checks for unexpected structure and compares RAW signal and clipping margin. A yellow region is shown for inspection or adjustment when needed. Choose a measured passing time in the list.

Exposure does not export a JSON handoff. At the chosen time, capture the current film's empty FB+F frame and two independent dark RAWs with the same camera, ISO, shutter and aperture. Load these in PRE tab 7 for signal/noise measurement. PRE includes those measured results in the film characterisation for NEG.

The last RAW folder is remembered. The local application log is `logs/camera41_exposure.jsonl`, available from **Log → Open complete log**. It includes timing, file choices, analyses and errors. Native dialog timing includes the user's file selection time. Logs are excluded from Git.

MATLAB and the bundled LibRaw probe are required. Original RAWs are unchanged. Automatic uniformity screening is heuristic and does not establish physical film identity or production qualification. GPL-3.0-or-later; see LICENSE and third_party/licenses.

## Handbooks / Handböcker

- [English handbook (PDF)](output/pdf/Camera41_Exposure_Handbook_EN.pdf)
- [Svensk handbok (PDF)](output/pdf/Camera41_Exposure_Handbook_SV.pdf)

Editable sources are in `docs/handbook/handbook_sv.json` and `handbook_en.json`. Rebuild both PDFs with `python tools/build_handbooks.py` (requires reportlab). The handbooks describe why FB+F exposure is used to avoid clipping, capture setup, automatic/manual areas, results, standalone operation and logging.

[Sammanfattning på svenska (PDF)](output/pdf/Camera41_Exposure_Sammanfattning_SV.pdf) - fristående ensidesguide för v0.1.0.
