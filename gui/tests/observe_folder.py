#!/usr/bin/env python3
"""Optional Omarchy observation of our newly requested output-folder window.

Do not capture screenshots, close windows or signal shared desktop processes.
Only retain the newly created window whose title names this fresh owned cohort.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', type=Path, required=True)
parser.add_argument('--tests', type=Path, required=True)
parser.add_argument('--media', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
output = args.output.resolve()
if output.exists() or output.is_relative_to(source.parent):
    raise SystemExit('Use a fresh external owned folder observation directory')
output.mkdir(parents=True)

def clients():
    result = subprocess.run(['/usr/bin/hyprctl', 'clients', '-j'], capture_output=True, check=True)
    return json.loads(result.stdout)

before = {c['address'] for c in clients()}
env = os.environ.copy()
env.update(QT_QPA_PLATFORM='wayland', TEST_BUNDLE=str(args.bundle.resolve()),
    TEST_MOCK=str(source / 'tests/mock_cli.py'), TEST_MEDIA=str(args.media.resolve()),
    TEST_PROJECT=str(source.parent), TEST_OUTPUT=str(output / 'export.mp4'),
    TEST_REAL_FOLDER_LAUNCH='1')
env.pop('QT_QUICK_BACKEND', None)
argv = [str(args.tests.resolve()), 'realRenderFrameAndPlayback', '-v1']
with (output / 'qt.stdout').open('wb') as out, (output / 'qt.stderr').open('wb') as err:
    result = subprocess.run(argv, env=env, stdout=out, stderr=err)
observation = {'argv': argv, 'exit_code': result.returncode, 'before_window_count': len(before),
    'requested_directory': str(output), 'new_matching_windows': [],
    'limits': 'Window creation/title observation only; no browsing contents, screenshot or desktop process cleanup'}
for _ in range(50):
    matching = [c for c in clients() if c['address'] not in before and c.get('title') == output.name
                and c.get('class') == 'org.gnome.Nautilus']
    if matching:
        for c in matching:
            pid = c['pid']
            stat = Path(f'/proc/{pid}/stat').read_text()
            start = stat[stat.rfind(')')+2:].split()[19]
            observation['new_matching_windows'].append({k: c[k] for k in ('address', 'pid', 'class', 'title')}
                | {'process_start_ticks': start})
        break
    time.sleep(.1)
(output / 'observation.json').write_text(json.dumps(observation, indent=2) + '\n')
if result.returncode or not observation['new_matching_windows']:
    raise SystemExit('Folder submission/window appearance not established; preserve observations')
print('Observed a new Nautilus window naming the exact requested owned output folder; preserved window/process')
