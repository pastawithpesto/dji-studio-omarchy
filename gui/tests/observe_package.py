#!/usr/bin/env python3
"""Observe/close only this fresh package's idle window via its exact PID/address."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--bundle', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
output = args.output.resolve()
if output.exists() or output.is_relative_to(source.parent):
    raise SystemExit('Use a fresh external observation directory')
output.mkdir(parents=True)
env = os.environ.copy()
env['QT_QPA_PLATFORM'] = 'wayland'
env.pop('QT_QUICK_BACKEND', None)
record = {'argv': [str(args.bundle.resolve() / 'native-stitched-flow')],
          'scope': 'Owned package idle window only; no peer window content or process signals'}
with (output / 'stdout.log').open('wb') as out, (output / 'stderr.log').open('wb') as err:
    process = subprocess.Popen(record['argv'], env=env, stdout=out, stderr=err, start_new_session=True)
    record['pid'] = process.pid
    stat = Path(f'/proc/{process.pid}/stat').read_text()
    fields = stat[stat.rfind(')')+2:].split()
    record.update(start_ticks=fields[19], group=fields[2], session=fields[3])
    window = None
    for _ in range(100):
        clients = json.loads(subprocess.run(['/usr/bin/hyprctl', 'clients', '-j'], capture_output=True, check=True).stdout)
        matches = [c for c in clients if c['pid'] == process.pid and c.get('title') == 'Native stitched view · experimental']
        if matches:
            window = matches[0]
            break
        if process.poll() is not None:
            break
        time.sleep(.1)
    if window:
        current = Path(f'/proc/{process.pid}/stat').read_text()
        now = current[current.rfind(')')+2:].split()
        if now[19] != fields[19] or now[2:4] != fields[2:4]:
            raise SystemExit('Identity ambiguous; preserve window/process')
        record['owned_window'] = {k: window[k] for k in ('address', 'pid', 'title', 'class')}
        result = subprocess.run(['/usr/bin/hyprctl', 'dispatch', 'hl.dsp.window.close({window = ' + json.dumps('address:' + window['address']) + '})'], capture_output=True)
        record['normal_close_submission'] = {'exit_code': result.returncode, 'stdout': result.stdout.decode()}
    try:
        record['exit_code'] = process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        record['pending'] = 'Owned window not closed; no automatic process kill or peer action'
    (output / 'observation.json').write_text(json.dumps(record, indent=2) + '\n')
    if not window or record.get('exit_code') != 0:
        raise SystemExit('Package appearance/normal close not established; preserved owned process if pending')
print('Actual packaged Qt app appeared and exited0 through normal close of its verified own idle window')
