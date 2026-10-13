#!/usr/bin/env python3
"""Run one assigned side of the frozen alternating schedule."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def atomic_json(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    os.replace(temp, path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--side', choices=['queue', 'manual'], required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    plan_path = root / 'PLAN.json'
    plan_raw = plan_path.read_bytes()
    plan_sha = hashlib.sha256(plan_raw).hexdigest()
    plan = json.loads(plan_raw)
    state_path = root / 'STATE.json'
    spec_path = root / 'SPEC.json'
    for name, expected in plan['code_sha256'].items():
        if sha(root / name) != expected:
            raise RuntimeError('Frozen helper changed: ' + name)
    if sha(spec_path) != plan['spec_sha256']:
        raise RuntimeError('Frozen spec changed')
    receipt = {'side': args.side, 'pid': os.getpid(), 'plan_sha256': plan_sha,
               'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    (root / (args.side + '-worker-receipt.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    own_results = []
    waiting = 0.0
    with (root / 'scheduler.lock').open('a+') as scheduling:
        while True:
            wait_start = time.perf_counter()
            preview = json.loads(state_path.read_text())
            if preview.get('abort') or preview['next_index'] == len(plan['schedule']):
                break
            if plan['schedule'][preview['next_index']]['side'] != args.side:
                time.sleep(.1)
                waiting += time.perf_counter() - wait_start
                continue
            try:
                fcntl.flock(scheduling, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                time.sleep(.1)
                waiting += time.perf_counter() - wait_start
                continue
            try:
                state = json.loads(state_path.read_text())
                if state['plan_sha256'] != plan_sha:
                    raise RuntimeError('Schedule belongs to another plan')
                if state.get('abort') or state['next_index'] == len(plan['schedule']):
                    break
                trial = plan['schedule'][state['next_index']]
                if trial['side'] != args.side:
                    time.sleep(.05)
                    waiting += time.perf_counter() - wait_start
                    continue
                for name, expected in plan['code_sha256'].items():
                    if sha(root / name) != expected:
                        raise RuntimeError('Frozen helper changed: ' + name)
                output = root / 'runs' / trial['id']
                command = [plan['python'], str(root / 'measure.py'), '--spec', str(spec_path),
                           '--target', trial['target'], '--mode', trial['mode'], '--side', args.side,
                           '--driver', plan['drivers'][args.side], '--output', str(output)]
                lock_wait = time.perf_counter()
                with Path(plan['import_lock']).open('a+') as native_lock:
                    fcntl.flock(native_lock, fcntl.LOCK_EX)
                    lock_wait = time.perf_counter() - lock_wait
                    process = subprocess.run(command, capture_output=True, text=True, timeout=240)
                (root / 'runs' / (trial['id'] + '-outer.json')).write_text(json.dumps({
                    'argv': command, 'returncode': process.returncode, 'stdout': process.stdout,
                    'stderr': process.stderr, 'resource_lock_wait_seconds': lock_wait}, indent=2) + '\n')
                measurement = json.loads((output / 'measurement.json').read_text())
                measurement['trial'] = trial
                measurement['plan_sha256'] = plan_sha
                (output / 'measurement-with-trial.json').write_text(json.dumps(measurement, indent=2) + '\n')
                own_results.append(measurement)
                state['completed'].append(trial['id'])
                state['next_index'] += 1
                state['updated_utc'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                if measurement['errors'] or process.returncode:
                    state['abort'] = {'trial': trial, 'errors': measurement['errors'],
                                      'outer_returncode': process.returncode}
                atomic_json(state_path, state)
                print(json.dumps({'trial': trial['id'], 'wall_seconds': measurement['wall_seconds'],
                                  'errors': measurement['errors']}), flush=True)
            finally:
                fcntl.flock(scheduling, fcntl.LOCK_UN)
            time.sleep(.02)
    summary = {**receipt, 'finished_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
               'completed_trials': len(own_results), 'scheduler_wait_seconds': waiting,
               'trial_ids': [r['trial']['id'] for r in own_results],
               'errors': [r['errors'] for r in own_results if r['errors']]}
    (root / (args.side + '-worker-summary.json')).write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary), flush=True)

if __name__ == '__main__':
    main()
