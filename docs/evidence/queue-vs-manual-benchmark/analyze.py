#!/usr/bin/env python3
"""Summarize the frozen comparison without pooling fresh and saved modes."""
from pathlib import Path
import hashlib
import json
import math
import statistics

ROOT = Path(__file__).resolve().parent
PLAN = json.loads((ROOT / 'PLAN.json').read_text())
SPEC = json.loads((ROOT / 'SPEC.json').read_text())

def stats(values):
    if not values:
        return None
    median = statistics.median(values)
    mad = statistics.median(abs(value - median) for value in values)
    return {'n': len(values), 'median': median, 'min': min(values), 'max': max(values),
            'median_absolute_deviation': mad, 'mad_fraction': mad / median if median else 0}

def main():
    records = []
    missing = []
    pins = {}
    for trial in PLAN['schedule']:
        path = ROOT / 'runs' / trial['id'] / 'measurement-with-trial.json'
        if not path.exists():
            missing.append(trial['id'])
            continue
        data = path.read_bytes()
        record = json.loads(data)
        if record['trial'] != trial:
            raise ValueError('Wrong trial metadata')
        pins[str(path.relative_to(ROOT))] = hashlib.sha256(data).hexdigest()
        record['cpu_workflow_seconds'] = record['cpu_workflow_user_seconds'] + record['cpu_workflow_system_seconds']
        record['cpu_monitor_seconds'] = record['cpu_monitor_user_seconds'] + record['cpu_monitor_system_seconds']
        records.append(record)
    modes = {}
    mismatches = []
    failures = [r['trial']['id'] for r in records if r['errors']]
    for mode in PLAN['modes']:
        targets = []
        for target in SPEC['targets']:
            sides = {}
            pair_results = []
            for side in ['manual', 'queue']:
                selected = [r for r in records if r['side'] == side and r['mode'] == mode and r['target'] == target['id']]
                sides[side] = {'wall_seconds': stats([r['wall_seconds'] for r in selected]),
                    'workflow_cpu_seconds': stats([r['cpu_workflow_seconds'] for r in selected]),
                    'observer_cpu_seconds': stats([r['cpu_monitor_seconds'] for r in selected]),
                    'peak_sampled_aggregate_rss_bytes': stats([r['peak_sampled_aggregate_rss_bytes'] for r in selected]),
                    'wait4_max_process_rss_kib': stats([r['wait4_max_process_rss_kib'] for r in selected]),
                    'trial_ids': [r['trial']['id'] for r in selected]}
            for pair in range(1, PLAN['N'] + 1):
                selected = {r['side']: r for r in records if r['mode'] == mode and r['target'] == target['id'] and r['trial']['pair'] == pair}
                if set(selected) != {'manual', 'queue'}:
                    continue
                manual, queue = selected['manual'], selected['queue']
                equal = (not manual['errors'] and not queue['errors'] and
                         manual['verification']['evidence_sha256'] == queue['verification']['evidence_sha256'])
                if not equal:
                    mismatches.append({'mode': mode, 'target': target['id'], 'pair': pair})
                pair_results.append({'pair': pair, 'exact_evidence_match': equal,
                                     'manual_wall_seconds': manual['wall_seconds'],
                                     'queue_wall_seconds': queue['wall_seconds'],
                                     'queue_strictly_faster': queue['wall_seconds'] < manual['wall_seconds']})
            row = {'target': target['id'], 'sides': sides, 'pairs': pair_results}
            if all(sides[s]['wall_seconds'] for s in sides):
                row['wall_improvement_fraction'] = 1 - sides['queue']['wall_seconds']['median'] / sides['manual']['wall_seconds']['median']
                row['cpu_regression_fraction'] = sides['queue']['workflow_cpu_seconds']['median'] / sides['manual']['workflow_cpu_seconds']['median'] - 1
                row['memory_regression_fraction'] = sides['queue']['peak_sampled_aggregate_rss_bytes']['median'] / sides['manual']['peak_sampled_aggregate_rss_bytes']['median'] - 1
                row['queue_faster_pairs'] = sum(pair['queue_strictly_faster'] for pair in pair_results)
                row['noise_pass'] = all(sides[s]['wall_seconds']['mad_fraction'] <= .10 for s in sides)
            targets.append(row)
        complete = all(all(row['sides'][s]['wall_seconds'] and row['sides'][s]['wall_seconds']['n'] == PLAN['N'] for s in ['manual', 'queue']) for row in targets)
        aggregate = {}
        if all(row['sides'][s]['wall_seconds'] for row in targets for s in ['manual', 'queue']):
            for side in ['manual', 'queue']:
                aggregate[side] = {'sum_wall_medians_seconds': sum(row['sides'][side]['wall_seconds']['median'] for row in targets),
                    'sum_cpu_medians_seconds': sum(row['sides'][side]['workflow_cpu_seconds']['median'] for row in targets)}
            aggregate['wall_improvement_fraction'] = 1 - aggregate['queue']['sum_wall_medians_seconds'] / aggregate['manual']['sum_wall_medians_seconds']
            aggregate['manual_to_queue_ratio'] = aggregate['manual']['sum_wall_medians_seconds'] / aggregate['queue']['sum_wall_medians_seconds']
        issues = []
        if not complete:
            issues.append('Incomplete frozen pair count')
        if any(r['errors'] for r in records if r['mode'] == mode):
            issues.append('Failed pipeline')
        if any(r['mode'] == mode for r in mismatches):
            issues.append('Raw Evidence differs')
        if complete and not all(row['noise_pass'] for row in targets):
            issues.append('Wall-time median absolute deviation exceeds10%')
        if complete and aggregate:
            if aggregate['wall_improvement_fraction'] < .10:
                issues.append('Aggregate wall improvement below10%')
            if any(row['queue_faster_pairs'] < math.ceil(.8 * PLAN['N']) for row in targets):
                issues.append('Queue wins fewer than80% of pairs for a DLL')
            if any(row['wall_improvement_fraction'] < -.05 for row in targets):
                issues.append('A DLL wall median regresses more than5%')
            if any(row['cpu_regression_fraction'] > .10 for row in targets):
                issues.append('A DLL CPU median regresses more than10%')
            if any(row['memory_regression_fraction'] > .10 for row in targets):
                issues.append('A DLL observed peak-memory median regresses more than10%')
        modes[mode] = {'complete': complete, 'targets': targets, 'aggregate': aggregate,
                       'quantitative_gate_issues': issues, 'quantitative_thresholds_pass': complete and not issues,
                       'adoption_attestation': False,
                       'adoption_limit': 'Import/first-analysis timing is combined; independent benchmark review and default adoption remain separate.'}
    result = {'plan_sha256': hashlib.sha256((ROOT / 'PLAN.json').read_bytes()).hexdigest(),
              'spec_sha256': hashlib.sha256((ROOT / 'SPEC.json').read_bytes()).hexdigest(),
              'complete': not missing, 'completed_trials': len(records), 'expected_trials': len(PLAN['schedule']),
              'missing_trials': missing, 'failures': failures, 'evidence_mismatches': mismatches,
              'modes': modes, 'measurement_sha256': pins,
              'scope': 'One function per three small DLLs. Scripted workflow processing only. Fresh and saved never pooled.'}
    output = ROOT / ('RESULTS.json' if not missing else 'RESULTS-provisional.json')
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['complete', 'completed_trials', 'failures', 'evidence_mismatches']}, indent=2))
    for mode, data in modes.items():
        print(mode, json.dumps(data['aggregate']), data['quantitative_gate_issues'])

if __name__ == '__main__':
    main()
