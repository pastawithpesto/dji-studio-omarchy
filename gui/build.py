#!/usr/bin/env python3
"""Portable isolated build/package with installed tools and pinned backends."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--ffmpeg', type=Path, default=Path('/usr/bin/ffmpeg'))
parser.add_argument('--ffprobe', type=Path, default=Path('/usr/bin/ffprobe'))
args = parser.parse_args()
source = Path(__file__).resolve().parent
project = source.parent
output = args.output.resolve()
if output.is_relative_to(project):
    raise SystemExit('Build outputs must be external to source Git')
backend_source_bytes = (source / 'backend-source-manifest.json').read_bytes()
if hashlib.sha256(backend_source_bytes).hexdigest() != 'f8b70eb52ad55456d26db197b030d309d3bd3991eb27551a2a950003d239d111':
    raise SystemExit('Frozen backend source manifest changed')
backend_source = json.loads(backend_source_bytes)
for name, expected in backend_source['files'].items():
    if hashlib.sha256((project / name).read_bytes()).hexdigest() != expected:
        raise SystemExit('Unchanged backend source identity differs: ' + name)
identity = {'source_directory': str(project), 'base': 'e03c38da6e430214f7a41cb0ecbd063e4ac29178'}
marker = output / '.native-flow-build.json'
if output.exists() and any(output.iterdir()) and (not marker.is_file() or json.loads(marker.read_text()) != identity):
    raise SystemExit('Preserve existing output directory with unknown ownership')
if args.ffprobe.resolve() != Path('/usr/bin/ffprobe').resolve():
    raise SystemExit('Unchanged CLI uses /usr/bin/ffprobe directly')
output.mkdir(parents=True, exist_ok=True)
marker.write_text(json.dumps(identity, indent=2) + '\n')
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
env = os.environ.copy()
env.update(CARGO='/usr/bin/cargo', RUSTC='/usr/bin/rustc', RUSTDOC='/usr/bin/rustdoc',
           PATH='/usr/bin:/bin', CARGO_TARGET_DIR=str(output / 'rust-target'))
commands = [
    ['/usr/bin/python3', str(source / 'verify_resources.py'), '--check'],
    ['/usr/bin/cargo', 'build', '--locked', '--release'],
    ['/usr/bin/cmake', '-S', str(source), '-B', str(output / 'qt-build')],
    ['/usr/bin/cmake', '--build', str(output / 'qt-build'), '--parallel', '2'],
]
# Never discard a prior successful or failed build's logs.
attempt = 1
while (output / f'build-attempt{attempt}.json').exists():
    attempt += 1
results = []
for index, argv in enumerate(commands):
    with (output / f'build-attempt{attempt}-{index}.log').open('wb') as log:
        result = subprocess.run(argv, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT)
    results.append({'argv': argv, 'exit_code': result.returncode})
    (output / f'build-attempt{attempt}.json').write_text(json.dumps(results, indent=2) + '\n')
    print(argv[0], result.returncode, flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)
bundle = output / 'bundle'
bundle.mkdir(exist_ok=True)
binpath = bundle / 'backend-bin'
binpath.mkdir(exist_ok=True)
for name, path in [('dji-reframe', output / 'rust-target/release/dji-reframe'),
                   ('native-stitched-flow', output / 'qt-build/native-stitched-flow')]:
    shutil.copy2(path, bundle / name)
for name, path in [('ffmpeg', args.ffmpeg.resolve()), ('ffprobe', args.ffprobe.resolve())]:
    destination = binpath / name
    if destination.is_symlink():
        if destination.resolve() != path:
            raise SystemExit('Preserve unexpected existing backend link')
    elif destination.exists():
        raise SystemExit('Preserve unexpected existing backend entry')
    else:
        destination.symlink_to(path)
backend = {'source_base': identity['base'], 'cli_sha256': sha(bundle / 'dji-reframe'),
    'ffmpeg': str(args.ffmpeg.resolve()), 'ffmpeg_sha256': sha(args.ffmpeg.resolve()),
    'ffprobe': str(args.ffprobe.resolve()), 'ffprobe_sha256': sha(args.ffprobe.resolve()),
    'environment': {'PATH': str(binpath), 'LANG': 'C', 'LC_ALL': 'C'},
    'resource_manifest_sha256': sha(source / 'resource-manifest.json')}
(bundle / 'backend.json').write_text(json.dumps(backend, indent=2) + '\n')
for name, path in [('ffmpeg', args.ffmpeg), ('ffprobe', args.ffprobe)]:
    with (output / f'build-attempt{attempt}-{name}-version.log').open('wb') as log:
        subprocess.run([str(path), '-version'], check=True, stdout=log, stderr=subprocess.STDOUT)
print('Bundle', bundle, flush=True)
