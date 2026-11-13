# Camera-41_exp v1.0.0 installation

Open `Camera-41_exp-1.0.0-python-macos.dmg` from the v1.0.0 release assets.
Drag **Camera-41_exp - Apple Silicon.app** to Applications on an M-series
Mac with macOS 14 Sonoma or later, or **Camera-41_exp - Intel.app** on an Intel
Mac with macOS 13 Ventura or later. Eject the disk image
and open the installed app. It includes Python and LibRaw and runs without
MATLAB, Homebrew, PRE or NEG. The interface is in English.

The apps are ad hoc signed. The disk image has no Apple notarisation.
Compare the disk image against its accompanying SHA-256 file with
`shasum -a 256 Camera-41_exp-1.0.0-python-macos.dmg`.

## First run

Use **Add FB+F RAWs…** to load Bayer RAWs of the same empty film-base sample
taken with fixed camera, ISO, aperture and lighting. Fill in **Light setup**
and **Film base + fog**, then tick **Same FB+F sample in all RAWs**. Use
**Preview selected** to inspect the yellow area or **Analyse RAW images**
to run the automatic measurement. Read **Results** and **Exposure comparison**.

The app remembers the last RAW folder. **Open log** opens the local diagnostic
log at `~/Library/Logs/Camera-41_exp/camera41_exp.jsonl`. Source runs write
`logs/camera41_exp.jsonl` in the checkout.

## Run or build from source

From the complete checkout, including `tools/bin/` and `tools/lib/`, run:

```sh
python3.13 -m venv .venv
.venv/bin/python -m pip install -r requirements-app.txt
.venv/bin/python -m camera41exp.app
```

You can also double-click `Start Camera-41_exp.command` after setup.
To build the standalone app, install `pyinstaller==6.22.3` in that
environment and run `.venv/bin/python tools/build_exp_python_app.py`.
Use a Python interpreter matching the target architecture. For the Intel build,
use the Ventura-compatible NumPy OpenBLAS wheel and pass
`--raw-probe /path/to/camera41_raw_probe_x86_64` with a statically linked probe
built for macOS 13 or earlier. The release source archive includes that probe.
The build is
written to `local-config/python-app/<architecture>/dist/`. The executable
accepts `--startup-check` and `--smoke-test /path/to/test.CR2`.

The legacy MATLAB entry point is `start.m` or `startCamera41_exp`.
See [PYTHON_ENVIRONMENT.md](PYTHON_ENVIRONMENT.md) for its runtime setup.
