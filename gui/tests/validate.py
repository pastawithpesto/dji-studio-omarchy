#!/usr/bin/env python3
"""Own external cohort: real media/Qt plus independent pinhole/output checks."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', type=Path, required=True)
parser.add_argument('--tests', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--headed', action='store_true')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
output = args.output.resolve()
if output.exists() or output.is_relative_to(source.parent):
    raise SystemExit('Use a fresh external output directory; preserve prior cohorts')
output.mkdir(parents=True)
config = json.loads((args.bundle / 'backend.json').read_text())
ffmpeg, ffprobe = config['ffmpeg'], config['ffprobe']
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
for name in ('ffmpeg', 'ffprobe'):
    if sha(config[name]) != config[name + '_sha256']:
        raise SystemExit('Pinned backend changed')
results = []

def run(name, argv, env=None, binary=False):
    if binary:
        r = subprocess.run(argv, env=env, capture_output=True)
        data, code = r.stdout, r.returncode
        (output / (name + '.stderr')).write_bytes(r.stderr)
    else:
        with (output / (name + '.stdout')).open('wb') as out, (output / (name + '.stderr')).open('wb') as err:
            r = subprocess.run(argv, env=env, stdout=out, stderr=err)
        data, code = (output / (name + '.stdout')).read_bytes(), r.returncode
    results.append({'name': name, 'argv': argv, 'exit_code': code})
    (output / 'commands.json').write_text(json.dumps(results, indent=2) + '\n')
    if code:
        raise SystemExit(f'{name} failed, see preserved logs')
    return data

w, h = 1280, 640
ppm = output / 'coordinate-gradient.ppm'
ppm.write_bytes(f'P6\n{w} {h}\n255\n'.encode() + bytes(
    channel for y in range(h) for x in range(w)
    for channel in (round(x * 255 / (w - 1)), round(y * 255 / (h - 1)), 128)))
media = output / 'known stitched ü.mkv'
run('fixture', [ffmpeg, '-nostdin', '-v', 'error', '-loop', '1', '-i', str(ppm),
                '-t', '2', '-r', '10', '-c:v', 'ffv1', '-pix_fmt', 'bgr0', str(media)])
env = os.environ.copy()
env.update(TEST_BUNDLE=str(args.bundle.resolve()), TEST_MOCK=str(source / 'tests/mock_cli.py'),
           TEST_MEDIA=str(media), TEST_PROJECT=str(source.parent),
           TEST_OUTPUT=str(output / 'render.mp4'), TEST_SCREENSHOT=str(output / 'window.png'))
if args.headed:
    env['QT_QPA_PLATFORM'] = 'wayland'
    env.pop('QT_QUICK_BACKEND', None)
else:
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
(output / 'environment.json').write_text(json.dumps({k: v for k, v in env.items()
    if k.startswith('TEST_') or k.startswith('QT_')}, indent=2) + '\n')
run('qt-runtime', [str(args.tests.resolve()), '-v1'], env)
# Independent explicit FFmpeg invocation corroborates the unchanged CLI pipeline.
vertical = math.degrees(2 * math.atan(1080 / 1920))
direct = output / 'direct-ffmpeg.mp4'
run('direct-render', [ffmpeg, '-nostdin', '-n', '-i', str(media), '-map', '0:v:0',
    '-map', '0:a?', '-vf', f'v360=input=equirect:output=flat:w=1920:h=1080:yaw=0:pitch=0:h_fov=90:v_fov={vertical}',
    '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', '-c:a', 'aac',
    '-movflags', '+faststart', str(direct)])
pins = {}
reference = None
projection = None
for name, file in [('cli', output / 'render.mp4'), ('qml', output / 'render.mp4.qml.mp4'), ('direct', direct)]:
    probe = json.loads(run(name + '-probe', [ffprobe, '-v', 'error', '-show_streams',
        '-count_frames', '-of', 'json', str(file)]))
    stream = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    if (stream['width'], stream['height'], stream['codec_name'], stream['pix_fmt'],
            int(stream['nb_read_frames'])) != (1920, 1080, 'h264', 'yuv420p', 20):
        raise SystemExit('Unexpected actual output format or frame count')
    raw = run(name + '-decode', [ffmpeg, '-nostdin', '-v', 'error', '-i', str(file),
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'], binary=True)
    digest = hashlib.sha256(raw).hexdigest()
    if len(raw) != 1920 * 1080 * 3 * 20:
        raise SystemExit('Incomplete actual decoded stream')
    pins[name] = {'encoded_sha256': sha(file), 'decoded_rgb_sha256': digest,
                  'decoded_bytes': len(raw), 'frames': 20}
    if reference is None:
        reference = digest
        samples = []
        for xf in (.1, .3, .5, .7, .9):
            for yf in (.1, .3, .5, .7, .9):
                x, y = round(xf * 1919), round(yf * 1079)
                u, v = 2*x/1919-1, (1-2*y/1079)*1080/1920
                lon, lat = math.atan2(u, 1), math.atan2(v, math.sqrt(1+u*u))
                expected = [round((lon/(2*math.pi)+.5)*255), round((.5-lat/math.pi)*255), 128]
                actual = list(raw[(y*1920+x)*3:(y*1920+x)*3+3])
                samples.append({'pixel': [x, y], 'expected': expected, 'actual': actual,
                                'errors': [abs(a-b) for a, b in zip(actual, expected)]})
        maximum = max(e for sample in samples for e in sample['errors'])
        projection = {'independent_model': 'pinhole rays -> longitude/latitude -> coordinate gradient',
                      'samples': samples, 'tolerance': 8, 'maximum_channel_error': maximum}
        (output / 'projection.json').write_text(json.dumps(projection, indent=2) + '\n')
        if maximum > 8:
            raise SystemExit('Independent geometric check failed')
    elif digest != reference:
        raise SystemExit('Complete decoded streams differ')
(output / 'results.json').write_text(json.dumps({'outputs': pins, 'projection_max_error': projection['maximum_channel_error'],
    'fixture': {'ppm_sha256': sha(ppm), 'media_sha256': sha(media), 'width': w, 'height': h},
    'scope': 'Synthetic already-stitched native validation only; no camera/Windows/audio parity',
    'headed': args.headed}, indent=2) + '\n')
print('Qt runtime and independent projection/full decoded stream checks passed')
