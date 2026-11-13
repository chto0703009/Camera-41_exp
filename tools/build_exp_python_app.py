#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a self-contained Camera-41_exp macOS app for the interpreter's CPU."""

import argparse
from importlib.metadata import distribution
import os
from pathlib import Path
import platform
import plistlib
import subprocess

from PyInstaller.__main__ import run

from build_dmg import app_source_digest

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-probe", type=Path, help="Package an alternative statically linked RAW probe.")
    options = parser.parse_args()
    cpu = platform.machine()
    if platform.system() != "Darwin" or cpu not in {"arm64", "x86_64"}:
        raise SystemExit("Use a native arm64 or x86_64 macOS Python interpreter.")
    output = ROOT / "local-config" / "python-app" / cpu
    physical_arm = subprocess.run(
        ["/usr/sbin/sysctl", "-n", "hw.optional.arm64"], capture_output=True, text=True
    ).stdout.strip() == "1"
    if cpu == "x86_64" and physical_arm:
        wrappers = output / "native-tools"
        wrappers.mkdir(parents=True, exist_ok=True)
        for tool in ("lipo", "codesign", "xcrun", "strip", "install_name_tool"):
            wrapper = wrappers / tool
            wrapper.write_text(f'#!/bin/sh\nexec /usr/bin/arch -arm64 /usr/bin/{tool} "$@"\n')
            wrapper.chmod(0o755)
        os.environ["PATH"] = str(wrappers) + os.pathsep + os.environ.get("PATH", os.defpath)
    minimum = {"arm64": "14.0", "x86_64": "13.0"}[cpu]
    version = (ROOT / "VERSION").read_text().strip()
    probe_name = f"camera41_raw_probe_{cpu}"
    probe = options.raw_probe or ROOT / "tools/bin" / probe_name
    if probe.name != probe_name:
        parser.error(f"Expected a RAW probe named {probe_name}.")
    if cpu == "x86_64" and options.raw_probe is None:
        parser.error("The Intel Ventura build needs a statically linked Ventura-compatible --raw-probe.")
    files = [
        (ROOT / "VERSION", "."),
        (ROOT / "resources/Camera41Exp.icns", "resources"),
        (ROOT / "LICENSE", "Notices"),
        (ROOT / "LICENSE_NOTICE.md", "Notices"),
        (ROOT / "third_party/licenses", "Notices/third-party"),
        (probe.resolve(), "tools/bin"),
    ]
    for package in ("numpy", "pillow", "pyobjc-core", "pyobjc-framework-Cocoa", "pyinstaller"):
        info = distribution(package)
        for file in info.files or ():
            if ".dist-info/" in str(file) and file.name.upper().startswith(("LICENSE", "COPYING", "NOTICE")):
                files.append((info.locate_file(file), f"Notices/{package}"))
    args = [
        "--noconfirm", "--windowed", "--name", "Camera-41_exp",
        "--icon", str(ROOT / "resources/Camera41Exp.icns"),
        "--target-architecture", cpu, "--osx-bundle-identifier", "se.camera41.exp",
        "--paths", str(ROOT), "--workpath", str(output / "build"),
        "--distpath", str(output / "dist"), "--specpath", str(output),
    ]
    for source, destination in files:
        args.extend(("--add-data", f"{source}:{destination}"))
    source_digest = app_source_digest()
    run([*args, str(ROOT / "camera41exp/app.py")])
    app = output / "dist/Camera-41_exp.app"
    info = app / "Contents/Info.plist"
    metadata = plistlib.loads(info.read_bytes())
    if source_digest != app_source_digest():
        raise SystemExit("Application sources changed during the build. Run the build again.")
    metadata.update(Camera41SourceSHA256=source_digest, CFBundleVersion=version, CFBundleShortVersionString=version,
                    LSMinimumSystemVersion=minimum)
    info.write_bytes(plistlib.dumps(metadata))
    subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)


if __name__ == "__main__":
    main()
