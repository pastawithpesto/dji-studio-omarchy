#!/usr/bin/env python3
"""Run one benchmark target through the unchanged reviewed REA queue."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time


QUEUE_ROOT = Path('/home/violence/Work/dji-rea-analysis-queue-20261012')
QUEUE_PATH = QUEUE_ROOT / 'tools/rea_analysis_queue.py'
QUEUE_COMMIT = '4f8a94a71451da5c99e6b4335d99bb6b94eba4bc'
QUEUE_SHA256 = '3f882a52ec95da0595dd460ef2650a025b586022d7ea2894291c0e7bb8ea0dc5'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha_file(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate JSON field: ' + key)
        result[key] = value
    return result


def load_json(path):
    def invalid_constant(value):
        raise ValueError('Invalid JSON number: ' + value)
    return json.loads(Path(path).read_bytes(), object_pairs_hook=no_duplicates,
                      parse_constant=invalid_constant)


def write_json(path, value):
    with Path(path).open('x') as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write('\n')


def build_manifest(spec, target_id, mode, output):
    require(type(spec.get('schema_version')) is int and spec['schema_version'] == 1,
            'Expected spec schema_version 1')
    targets = spec.get('targets')
    require(isinstance(targets, list), 'Spec targets must be a list')
    matches = [target for target in targets if target.get('id') == target_id]
    require(len(matches) == 1, 'Expected one target with the requested ID')
    target = matches[0]
    job = {'id': target['id'], 'binary': target['binary'],
           'address': target['address'], 'producer': target['producers'][mode],
           'byte_witnesses': target['byte_witnesses'],
           'saved_evidence': [target['saved_evidence']] if mode == 'saved' else []}
    manifest = {'schema_version': 1,
                'queue_id': 'benchmark-' + mode + '-' + target_id + '-' + output.name,
                'max_input_bytes': spec.get('max_input_bytes', 64 * 1024 * 1024),
                'jobs': [job]}
    if mode == 'fresh':
        manifest['runner'] = spec['runner']
        manifest['resource_grant'] = spec['resource_grant']
    return target, manifest


def check_queue_source():
    observed_hash = sha_file(QUEUE_PATH)
    require(observed_hash == QUEUE_SHA256, 'Reviewed queue source hash changed')
    observed_commit = subprocess.run(
        ['git', '-C', str(QUEUE_ROOT), 'rev-parse', 'HEAD'],
        check=True, capture_output=True, text=True, timeout=10).stdout.strip()
    require(observed_commit == QUEUE_COMMIT, 'Reviewed queue commit changed')
    tracked_clean = subprocess.run(
        ['git', '-C', str(QUEUE_ROOT), 'diff', 'HEAD', '--exit-code'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10).returncode == 0
    require(tracked_clean, 'Reviewed queue tracked source changed')
    return {'path': str(QUEUE_PATH), 'sha256': observed_hash,
            'repository': str(QUEUE_ROOT), 'commit': observed_commit,
            'tracked_clean': tracked_clean, 'python': sys.executable,
            'python_version': sys.version}


def run(spec_path, target_id, mode, output):
    require(output.is_absolute(), 'Output path must be absolute')
    require(spec_path.is_absolute(), 'Spec path must be absolute')
    require(not output.is_symlink(), 'Output path must not be a symbolic link')
    output.mkdir(parents=True, exist_ok=True)
    for name in ('manifest.json', 'queue', 'result.json', 'report.json',
                 'queue-source.json', 'queue-command.json',
                 'queue-stdout.raw', 'queue-stderr.raw', 'driver-stages.json'):
        require(not (output / name).exists(), 'Trial output already exists: ' + name)
    result = {'status': 'failed', 'evidence_path': None, 'report_path': None, 'error': None}
    stages = []
    stage_start = time.monotonic()
    try:
        source = check_queue_source()
        write_json(output / 'queue-source.json', source)
        stages.append({'stage': 'queue_source_checks',
                       'wall_seconds': time.monotonic() - stage_start})
        stage_start = time.monotonic()
        spec = load_json(spec_path)
        target, manifest = build_manifest(spec, target_id, mode, output)
        write_json(output / 'manifest.json', manifest)
        stages.append({'stage': 'manifest_generation',
                       'wall_seconds': time.monotonic() - stage_start})
        command = [sys.executable, str(QUEUE_PATH), 'run', str(output / 'manifest.json'),
                   '--output', str(output / 'queue')]
        if mode == 'fresh':
            command.append('--allow-live')
        write_json(output / 'queue-command.json', {'argv': command})
        stage_start = time.monotonic()
        with (output / 'queue-stdout.raw').open('xb') as stdout, \
                (output / 'queue-stderr.raw').open('xb') as stderr:
            proc = subprocess.run(command, stdout=stdout, stderr=stderr, check=False)
        stages.append({'stage': 'queue_child', 'wall_seconds': time.monotonic() - stage_start,
                       'returncode': proc.returncode})
        stage_start = time.monotonic()
        queue_report = load_json(output / 'queue-stdout.raw')
        require(len(queue_report.get('results', [])) == 1, 'Expected one queue result')
        record = queue_report['results'][0]
        require(proc.returncode == 0 and record.get('status') == 'evidence_ready',
                record.get('error') or 'Queue did not return evidence_ready')
        require(record.get('input_verification') == 'verified', 'Source was not verified')
        require(record.get('resumed') is False, 'Queue reused a prior trial')
        require(record.get('mode') == ('saved_evidence' if mode == 'saved'
                                       else 'live_cli_snapshot_or_import'),
                'Queue evidence mode does not match the trial mode')
        if mode == 'fresh':
            require(not record.get('cleanup', {}).get('surviving_processes'),
                    'Owned REA processes survived cleanup')
        evidence_path = Path(record['attempt']) / 'evidence.json'
        evidence = load_json(evidence_path)
        normalized = evidence['normalized_result']
        coverage = record['coverage']
        report = {'source_sha256': target['binary']['sha256'],
                  'address': target['address'], 'provider': evidence['provider'],
                  'analysis_profile_digest': evidence['analysis_profile']['digest'],
                  'pseudocode': normalized['pseudocode'], 'assembly': normalized['assembly'],
                  'body_ranges': normalized['procedure']['body']['ranges'],
                  'witness_bytes': coverage['witness_bytes'],
                  'source_byte_match': coverage['source_byte_match'],
                  'limitations': record['limitations'], 'producer': record['producer'],
                  'mode': mode, 'coverage': coverage, 'evidence_id': evidence['evidence_id'],
                  'queue_report_path': queue_report['report_path'],
                  'queue_stdout_path': str(output / 'queue-stdout.raw'),
                  'queue_attempt_path': record['attempt'],
                  'queue_record_path': str(Path(record['attempt']) / 'record.json')}
        write_json(output / 'report.json', report)
        result.update(status='ok', evidence_path=str(evidence_path),
                      report_path=str(output / 'report.json'))
        stages.append({'stage': 'required_report_write',
                       'wall_seconds': time.monotonic() - stage_start})
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        result['error'] = str(exc)
        stages.append({'stage': 'failed_stage', 'wall_seconds': time.monotonic() - stage_start})
    result['stages'] = stages
    write_json(output / 'driver-stages.json', stages)
    write_json(output / 'result.json', result)
    return 0 if result['status'] == 'ok' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spec', required=True, type=Path)
    parser.add_argument('--target', required=True)
    parser.add_argument('--mode', required=True, choices=('fresh', 'saved'))
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        return run(args.spec, args.target, args.mode, args.output)
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
