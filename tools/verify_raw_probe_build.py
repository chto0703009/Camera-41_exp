#!/usr/bin/env python3
"""Verify and describe a locally built Camera-41 LibRaw probe."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def command_output(command: list[str]) -> str:
    return subprocess.run(
        command, check=True, text=True, capture_output=True
    ).stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-architecture")
    parser.add_argument("--expected-libraw")
    args = parser.parse_args()

    binary = args.binary.resolve()
    source = args.source.resolve()
    assert binary.is_file(), f"Probe binary missing: {binary}"
    assert source.is_file(), f"Probe source missing: {source}"
    build_info = json.loads(command_output([str(binary), "--build-info"]))
    assert build_info["Schema"] == "camera41.raw-probe-build-info.v0.2"
    architecture = str(build_info["ProbeArchitecture"])
    libraw_version = str(build_info["LibRawVersion"])
    if args.expected_architecture:
        assert architecture == args.expected_architecture, (
            f"Expected {args.expected_architecture}, got {architecture}"
        )
    if args.expected_libraw:
        assert libraw_version == args.expected_libraw, (
            f"Expected {args.expected_libraw}, got {libraw_version}"
        )
    file_description = command_output(["/usr/bin/file", str(binary)])
    assert architecture in file_description, file_description
    compiler = command_output(["/usr/bin/clang++", "--version"]).splitlines()[0]

    manifest = {
        "Schema": "camera41.raw-probe-build.v0.2",
        "Status": "VALID",
        "ProbeArchitecture": architecture,
        "LibRawVersion": libraw_version,
        "BinarySizeBytes": binary.stat().st_size,
        "BinarySHA256": sha256(binary),
        "SourceSHA256": sha256(source),
        "Compiler": compiler,
        "BuildPlatform": platform.platform(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        f"Camera-41 RAW probe build: VALID, {architecture}, "
        f"LibRaw {libraw_version}, SHA-256 {manifest['BinarySHA256']}"
    )


if __name__ == "__main__":
    main()
