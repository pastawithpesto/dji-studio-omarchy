#!/usr/bin/env python3
"""Check all recorded trials without a new native analysis."""
from pathlib import Path
import hashlib
import importlib.util
import json

ROOT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    plan = json.loads((ROOT / 'PLAN.json').read_text())
    spec = json.loads((ROOT / 'SPEC.json').read_text())
    module_spec = importlib.util.spec_from_file_location('monitor', ROOT / 'measure.py')
    monitor = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(monitor)
    assert digest(ROOT / 'SPEC.json') == plan['spec_sha256']
    for name, expected in plan['code_sha256'].items():
        assert digest(ROOT / name) == expected, name
    assert digest(spec['queue']['path']) == spec['queue']['sha256']
    for file in spec['runner']['files']:
        assert digest(file['path']) == file['sha256']
    tree = Path(spec['runner']['runtime_tree']['path'])
    runtime = hashlib.sha256()
    for file in sorted(tree.rglob('*')):
        assert not file.is_symlink()
        if file.is_file():
            name = file.relative_to(tree).as_posix().encode()
            runtime.update(len(name).to_bytes(8, 'big'))
            runtime.update(name)
            runtime.update(bytes.fromhex(digest(file)))
    assert runtime.hexdigest() == spec['runner']['runtime_tree']['sha256']
    targets = {t['id']: t for t in spec['targets']}
    pairs = {}
    records = []
    for trial in plan['schedule']:
        output = ROOT / 'runs' / trial['id']
        record = json.loads((output / 'measurement-with-trial.json').read_text())
        assert record['trial'] == trial
        assert record['plan_sha256'] == digest(ROOT / 'PLAN.json')
        assert not record['errors'] and not record['surviving_processes']
        assert record['returncode'] == 0
        assert record['peak_sampled_aggregate_rss_bytes'] <= spec['limits']['aggregate_rss_bytes']
        assert record['wall_seconds'] <= spec['limits']['pipeline_timeout_seconds']
        assert record['java_heap_arguments'] == (['-Xmx768M'] if trial['mode'] == 'fresh' else [])
        verification = monitor.verify(spec, targets[trial['target']], trial['mode'], output)
        assert verification == record['verification'], trial['id']
        result = json.loads((output / 'result.json').read_text())
        evidence = monitor.evidence_object(json.loads(Path(result['evidence_path']).read_text()))
        report = json.loads(Path(result['report_path']).read_text())
        key = (trial['mode'], trial['target'], trial['pair'])
        pairs.setdefault(key, {})[trial['side']] = (evidence, report)
        records.append({'trial_id': trial['id'], 'record_sha256': digest(output / 'measurement-with-trial.json'),
                        'evidence_sha256': verification['evidence_sha256'],
                        'raw_evidence_sha256': verification['raw_evidence_sha256'],
                        'report_sha256': verification['report_sha256']})
    differences = []
    for key, sides in pairs.items():
        assert set(sides) == {'manual', 'queue'}
        manual_evidence, manual_report = sides['manual']
        queue_evidence, queue_report = sides['queue']
        assert manual_evidence == queue_evidence, key
        shared = set(manual_report) & set(queue_report)
        for name in shared - {'limitations'}:
            assert manual_report[name] == queue_report[name], (key, name)
        assert list(dict.fromkeys(manual_report['limitations'])) == queue_report['limitations']
        differences.append({'mode': key[0], 'target': key[1], 'pair': key[2],
                            'raw_evidence_exact_match': True,
                            'shared_report_fields_match_except_duplicate_limitations': True,
                            'manual_limitation_count': len(manual_report['limitations']),
                            'queue_limitation_count': len(queue_report['limitations']),
                            'unique_limitations_exact_match': True,
                            'manual_only_report_fields': sorted(set(manual_report) - shared),
                            'queue_only_report_fields': sorted(set(queue_report) - shared)})
    state = json.loads((ROOT / 'STATE.json').read_text())
    assert state['abort'] is None
    assert state['completed'] == [trial['id'] for trial in plan['schedule']]
    result = {'plan_sha256': digest(ROOT / 'PLAN.json'), 'spec_sha256': digest(ROOT / 'SPEC.json'),
              'all_frozen_code_and_runtime_pins_match': True,
              'all_original_and_saved_input_pins_match': True,
              'trial_count': len(records), 'pair_count': len(pairs), 'errors': [],
              'all_recorded_verification_recomputed': True, 'all_resource_and_cleanup_records_pass': True,
              'records': records, 'pairs': differences,
              'limit': 'Read-only artifact check. No new native analysis. Observed memory is sampled RSS, not an exact physical peak.'}
    (ROOT / 'ROOT-POSTCHECK.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['trial_count', 'pair_count', 'errors']}))

if __name__ == '__main__':
    main()
