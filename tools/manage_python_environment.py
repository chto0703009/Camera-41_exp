#!/usr/bin/env python3
"""Install and verify the identical local Python environment used by the app suite."""
from __future__ import annotations
import argparse
import base64
import importlib.util
from datetime import datetime, timezone
import hashlib
import importlib
import importlib.metadata as metadata
import json
import os
import platform
from pathlib import Path
import subprocess
import sys
import tempfile
import venv

ROOT = Path(__file__).absolute().parent.parent
MODULES = {'numpy': 'numpy', 'h5py': 'h5py', 'opencv-python-headless': 'cv2',
           'matplotlib': 'matplotlib', 'reportlab': 'reportlab', 'pypdf': 'pypdf',
           'colour-science': 'colour', 'typing-extensions': 'typing_extensions', 'pillow': 'PIL', 'Pillow': 'PIL', 'fonttools': 'fontTools', 'python-dateutil': 'dateutil', 'rpds-py': 'rpds', 'OpenEXR': 'OpenEXR', 'jsonschema': 'jsonschema', 'referencing': 'referencing'}


def executable(root: Path) -> Path:
    return root / '.venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')


def specifications(file: Path) -> dict[str, str]:
    result = {}
    for line in file.read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if not line:
            continue
        if line.startswith('-r '):
            result.update(specifications(file.parent / line[3:].strip()))
        else:
            name, sep, version = line.partition('==')
            if not sep or not name.strip() or not version.strip():
                raise ValueError(f'{file.name}: use explicit package==version pins: {line}')
            result[name.strip()] = version.strip()
    return result


def native_architecture() -> str:
    if sys.platform != 'darwin':
        return platform.machine()
    result = subprocess.run(['/usr/sbin/sysctl', '-n', 'hw.optional.arm64'], capture_output=True, text=True)
    return 'arm64' if result.returncode == 0 and result.stdout.strip() == '1' else 'x86_64'


def pin_native_interpreter(root: Path) -> None:
    # A single native slice prevents a universal Python from inheriting Rosetta preference.
    if sys.platform != 'darwin':
        return
    desired = native_architecture()
    for file in (root / '.venv/bin').glob('python*'):
        if not file.is_file() or file.is_symlink():
            continue
        result = subprocess.run(['/usr/bin/lipo', '-archs', str(file)], capture_output=True, text=True)
        slices = result.stdout.split() if result.returncode == 0 else []
        if desired not in slices or len(slices) < 2:
            continue
        pending = file.with_name(file.name + '.native-tmp')
        try:
            subprocess.run(['/usr/bin/lipo', str(file), '-thin', desired, '-output', str(pending)], check=True)
            pending.chmod(file.stat().st_mode)
            pending.replace(file)
        finally:
            pending.unlink(missing_ok=True)


def health(root: Path, profile: str) -> dict:
    expected = root / '.venv'
    if Path(sys.prefix).resolve() != expected.resolve() or sys.prefix == sys.base_prefix:
        raise RuntimeError(f'Wrong environment: {sys.prefix}; expected {expected}. Recreate the local venv.')
    if sys.version_info[:3] != (3, 13, 6):
        raise RuntimeError('The unified environment requires Python 3.13.6 in every program.')
    cfg = (expected / 'pyvenv.cfg').read_text().lower()
    if 'include-system-site-packages = false' not in cfg or sys.flags.isolated != 1:
        raise RuntimeError('The runtime must be isolated from system/user packages and PYTHONPATH.')
    requirements = root / 'requirements.txt'
    failures, packages = [], {}
    for package, version in specifications(requirements).items():
        try:
            actual = metadata.version(package)
            module = importlib.import_module(MODULES.get(package, package.replace('-', '_')))
            location = Path(module.__file__).resolve()
            if not location.is_relative_to(expected.resolve()):
                raise RuntimeError(f'import outside the venv: {location}')
            if actual != version:
                raise RuntimeError(f'{actual} installed; requirements specify {version}')
            packages[package] = {'Version': actual, 'Module': module.__name__, 'Location': str(location)}
        except Exception as error:
            failures.append(f'{package}: {error}')
    if failures:
        raise RuntimeError('\n'.join(failures))
    # Exercise compiled functions, rather than checking only package metadata.
    import numpy as np
    import h5py
    import cv2
    values = np.arange(18, dtype=np.float64).reshape(2, 3, 3) / 20
    assert np.isfinite(np.power(10.0, values)).all()
    assert cv2.cvtColor(np.zeros((3, 3, 3), np.uint8), cv2.COLOR_BGR2GRAY).shape == (3, 3)
    with tempfile.TemporaryDirectory() as folder:
        file = Path(folder) / 'probe.h5'
        with h5py.File(file, 'w') as handle:
            handle.create_dataset('values', data=values, compression='gzip')
        with h5py.File(file) as handle:
            assert np.array_equal(handle['values'][:], values)
    kernel_status = 'NOT_APPLICABLE'
    if (root / 'config/python_buchler_reference.json').is_file() and (root / 'tools/invert_buchler_numpy.py').is_file():
        reference = json.loads((root / 'config/python_buchler_reference.json').read_text())
        stored = np.frombuffer(base64.b64decode(reference['InputFloat32LittleEndianBase64']), dtype='<f4').reshape(reference['Shape'])
        spec = importlib.util.spec_from_file_location('camera41_kernel_probe', root / 'tools/invert_buchler_numpy.py')
        kernel = importlib.util.module_from_spec(spec);spec.loader.exec_module(kernel)
        ranges = np.column_stack((reference['AcceptedDensityMinimumRGB'], reference['AcceptedDensityMaximumRGB']))
        _, positive, mask, _ = kernel.compute_tile((0,stored),np.asarray(reference['WhiteBalanceMultipliersRGB']),np.asarray(reference['DensityBalanceExponentsRGB']),reference['Scale'],ranges)
        if hashlib.sha256(positive.astype('<f4').tobytes()).hexdigest() != reference['OutputFloat32LittleEndianSHA256'] or hashlib.sha256(mask.tobytes()).hexdigest() != reference['MaskUInt8SHA256']:
            raise RuntimeError('The existing numerical kernel reference changed. Review the runtime update before inversion.')
        kernel_status = 'PASS'
    # Exercise shared compiled and report dependencies in every local environment.
    from scipy.spatial import cKDTree
    assert cKDTree([[0., 0.], [1., 1.]]).query([0., 0.])[0] == 0.
    import colour
    assert np.isfinite(colour.XYZ_to_Lab(np.array([.2, .2, .2]))).all()
    import imagecodecs
    sample = bytes(range(255))
    assert imagecodecs.lzw_decode(imagecodecs.lzw_encode(sample)) == sample
    import io
    from reportlab.pdfgen import canvas
    from pypdf import PdfReader
    pdf = io.BytesIO()
    document = canvas.Canvas(pdf); document.drawString(40, 800, 'Unified runtime'); document.save()
    assert len(PdfReader(io.BytesIO(pdf.getvalue())).pages) == 1
    installed = {name.lower().replace('_', '-'): version for name, version in specifications(requirements).items()}
    actual = {dist.metadata['Name'].lower().replace('_', '-'): dist.version for dist in metadata.distributions()}
    if actual != installed:
        raise RuntimeError(f'Environment differs from the full package lock: {actual.keys() ^ installed.keys()}')
    subprocess.run([sys.executable, '-I', '-m', 'pip', 'check'], check=True, capture_output=True, text=True)
    return {'Schema': 'camera41.python-environment.v1', 'Status': 'PASS',
            'CheckedAt': datetime.now(timezone.utc).isoformat(), 'EnvironmentRoot': str(expected),
            'Executable': str(executable(root)), 'PythonVersion': sys.version.split()[0], 'Architecture': platform.machine(), 'NativeArchitecture': native_architecture(),
            'Profile': 'unified', 'Isolated': True, 'Packages': packages,
            'RequirementsSHA256': hashlib.sha256(requirements.read_bytes()).hexdigest(),
            'RuntimeRequirementsSHA256': hashlib.sha256((root / 'requirements.txt').read_bytes()).hexdigest(),
            'CompiledModuleSmokeTests': 'PASS', 'HDF5Version': h5py.version.hdf5_version, 'PipCheck': 'PASS', 'ExistingBuchlerReference': kernel_status, 'EnvironmentStandard': 'camera41-suite.v1'}


def child_check(root: Path, profile: str) -> dict:
    command = [str(executable(root)), '-I', str(Path(__file__).absolute()),
               'probe', '--root', str(root), '--profile', profile]
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout)


def manage(root: Path, mode: str, profile: str, wheelhouse: Path | None = None) -> dict:
    target = root / '.venv'
    local = root / 'local-config'
    recorded = local / 'python_environment.json'
    if recorded.exists() and mode not in ('rebuild', 'sync'):
        previous = json.loads(recorded.read_text())
        if Path(previous['EnvironmentRoot']).resolve() != target.resolve():
            raise RuntimeError('The installation has moved. Rebuild the local Python environment on this computer.')
    if mode == 'check':
        return child_check(root, profile)
    previous_metadata = {name: (local / name).read_bytes() if (local / name).is_file() else None
                         for name in ('python-lock.txt', 'python_environment.json')}
    exists = target.exists()
    backup = None
    # Sync is transactional too: a failed package change must not break the old runtime.
    if mode in ('rebuild', 'sync') and exists:
        backup = root / ('.venv.backup_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
        target.rename(backup)
        exists = False
    try:
        if not exists:
            if sys.version_info[:3] != (3, 13, 6):
                raise RuntimeError('Create the unified environment with Python 3.13.6.')
            print(f'Creating {target}', flush=True)
            # Standalone macOS Python locates libpython relative to its executable.
            # Symlinks keep that base layout intact; copying the binary breaks it.
            venv.EnvBuilder(with_pip=True, system_site_packages=False,
                            symlinks=(os.name != 'nt')).create(target)
            pin_native_interpreter(root)
            command = [str(executable(root)), '-I', '-m', 'pip', '--isolated', 'install', '--only-binary=:all:']
            if wheelhouse is not None:
                command += ['--no-index', '--find-links', str(wheelhouse)]
            subprocess.run(command + ['-r', str(root / 'requirements.txt')], check=True)
        report = child_check(root, profile)
        local.mkdir(exist_ok=True)
        freeze = subprocess.check_output([str(executable(root)), '-I', '-m', 'pip', 'freeze', '--all'], text=True)
        report['InstalledLockSHA256'] = hashlib.sha256(freeze.encode()).hexdigest()
        report['BackupEnvironment'] = str(backup) if backup else None
        lock_file = local / 'python-lock.txt'
        lock_file.write_text(freeze, encoding='utf-8')
        pending = local / 'python_environment.json.tmp'
        pending.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        pending.replace(recorded)
        return report
    except Exception:
        if backup is not None:
            failed = root / ('.venv.failed_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
            if target.exists():
                target.rename(failed)
            backup.rename(target)
        # Keep provenance consistent with the restored environment if recording fails.
        for name, content in previous_metadata.items():
            file = local / name
            if content is None:
                file.unlink(missing_ok=True)
            else:
                file.write_bytes(content)
        (local / 'python_environment.json.tmp').unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['ensure', 'check', 'sync', 'rebuild', 'probe'])
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--profile', choices=['runtime', 'tools', 'unified'], default='runtime')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--wheelhouse', type=Path, help='Optional local wheel cache for offline installation')
    options = parser.parse_args()
    root = options.root.absolute()
    try:
        report = health(root, options.profile) if options.mode == 'probe' else manage(root, options.mode, options.profile, options.wheelhouse)
        text = json.dumps(report, indent=2)
        if options.output:
            options.output.write_text(text + '\n', encoding='utf-8')
        else:
            print(text)
    except Exception as error:
        print(f'Camera-41 Python environment failed:\n{error}\n'
              'MATLAB repair: use this program’s setup_python_environment("sync") or existing Python setup command.\n'
              'Moved/new computer: rebuild this program’s own .venv with Python 3.13.6.\n'
              'Edit requirements.txt to change pinned runtime versions.', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
