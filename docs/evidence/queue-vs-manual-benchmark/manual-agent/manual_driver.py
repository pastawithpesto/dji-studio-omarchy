#!/usr/bin/env python3
"""Repeat direct REA calls and static evidence checks without queue imports."""
import argparse
import hashlib
import json
import os
import resource
import signal
from pathlib import Path
import struct
import subprocess
import sys
import time


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def pe_offset(data, address, length):
    """Map one complete file-backed range. Reject ambiguous section mappings."""
    require(len(data) >= 64 and data[:2] == b'MZ', 'Missing PE DOS header')
    nt = struct.unpack_from('<I', data, 0x3c)[0]
    require(nt + 24 <= len(data) and data[nt:nt+4] == b'PE\0\0', 'Missing PE signature')
    sections = struct.unpack_from('<H', data, nt + 6)[0]
    opt_size = struct.unpack_from('<H', data, nt + 20)[0]
    opt = nt + 24
    require(opt_size >= 64 and opt + opt_size <= len(data), 'Truncated PE optional header')
    magic = struct.unpack_from('<H', data, opt)[0]
    require(magic in (0x10b, 0x20b), 'Unsupported PE optional header')
    image_base = struct.unpack_from('<Q' if magic == 0x20b else '<I', data, opt + (24 if magic == 0x20b else 28))[0]
    header_size = struct.unpack_from('<I', data, opt + 60)[0]
    rva = address - image_base
    require(rva >= 0 and length > 0, 'Invalid PE address or byte count')
    matches = []
    if rva + length <= header_size and rva + length <= len(data):
        matches.append(rva)
    table = opt + opt_size
    require(table + sections * 40 <= len(data), 'Truncated PE section table')
    for index in range(sections):
        sec = table + 40 * index
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from('<IIII', data, sec + 8)
        delta = rva - virtual_address
        if delta >= 0 and delta + length <= raw_size and delta + length <= max(virtual_size, raw_size):
            offset = raw_pointer + delta
            require(offset + length <= len(data), 'PE section raw bytes exceed source')
            matches.append(offset)
    require(len(matches) == 1, 'PE body range has missing or ambiguous file mapping')
    return matches[0]


def normalize_address(value):
    require(isinstance(value, str) and value.startswith('0x'), 'Expected default-space hexadecimal address')
    return int(value, 16)


def check_source(target):
    path = Path(target['binary']['path'])
    data = path.read_bytes()
    require(sha256(data) == target['binary']['sha256'], 'Complete source SHA-256 mismatch')
    return data


def check_witness_inputs(target, source):
    for witness in target['byte_witnesses']:
        raw = bytes.fromhex(witness['hex'])
        address = normalize_address(witness['address'])
        offset = pe_offset(source, address, len(raw))
        require(offset == witness['file_offset'], 'Supplied witness PE file offset mismatch')
        require(source[offset:offset+len(raw)] == raw, 'Supplied witness differs from original file bytes')
        require(bool(witness['provenance']), 'Missing static witness provenance')


def check_evidence(evidence, target, source):
    require(evidence['operation'] == 'analyze_function', 'Unexpected evidence operation')
    subject = evidence['subject']
    require(subject['digest']['sha256'] == target['binary']['sha256'], 'Evidence source SHA-256 mismatch')
    require(Path(subject['local_path']).resolve() == Path(target['binary']['path']).resolve(), 'Evidence source path mismatch')
    require(evidence['provider']['id'] == 'ghidra', 'Expected Ghidra provider')
    profile = evidence['analysis_profile']
    require(profile and profile['digest'], 'Missing evidence analysis profile')
    require(profile['provider'] == evidence['provider'], 'Profile provider mismatch')
    result = evidence['normalized_result']
    proc = result['procedure']
    entry = normalize_address(proc['address'])
    require(entry == normalize_address(target['address']), 'Exact function address mismatch')
    body = proc['body']
    require(body.get('available') is True and body.get('contains_entry') is True, 'Function body unavailable or does not contain entry')
    ranges = body['ranges']
    require(isinstance(ranges, list) and ranges, 'Missing function body ranges')
    pseudocode = result['pseudocode']
    assembly = result['assembly']
    require(isinstance(pseudocode, str) and pseudocode.strip(), 'Missing raw pseudocode')
    require(isinstance(assembly, list) and assembly and all(isinstance(x, str) for x in assembly), 'Missing raw assembly')
    observed = []
    full_witness = []
    count = 0
    for item in ranges:
        start, end = normalize_address(item['start']), normalize_address(item['end'])
        require(end >= start, 'Invalid inclusive body range')
        require(not observed or start > observed[-1][1], 'Unsorted or overlapping function body ranges')
        observed.append((start, end))
        length = end - start + 1
        offset = pe_offset(source, start, length)
        raw = source[offset:offset+length]
        cursor = start
        while cursor <= end:
            matches = []
            for supplied in target['byte_witnesses']:
                wa = normalize_address(supplied['address'])
                wb = bytes.fromhex(supplied['hex'])
                if wa <= cursor < wa + len(wb):
                    matches.append((supplied, wa, wb))
            require(len(matches) == 1, 'Body byte lacks one exact supplied static witness')
            supplied, wa, wb = matches[0]
            take = min(end - cursor + 1, wa + len(wb) - cursor)
            local = cursor - start
            require(raw[local:local+take] == wb[cursor-wa:cursor-wa+take], 'Full body witness mismatch')
            cursor += take
        full_witness.append({'address':item['start'], 'file_offset':offset, 'hex':raw.hex(), 'provenance':'Original-file PE bytes checked against supplied static provider witness'})
        count += length
    require(count == body['total_bytes'], 'Function body byte count mismatch')
    require(any(start <= entry <= end for start,end in observed), 'Entry absent from body ranges')
    return {
        'source_sha256':sha256(source), 'address':proc['address'],
        'provider':evidence['provider'], 'analysis_profile_digest':profile['digest'],
        'pseudocode':pseudocode, 'assembly':assembly, 'body_ranges':ranges,
        'witness_bytes':count, 'byte_witnesses':full_witness, 'source_byte_match':True,
        'limitations':evidence['limitations'] + result.get('limitations', []),
    }


def producer_checks(report, producer):
    # A frozen producer commitment can name any of these comparable fields.
    for key in ('source_sha256', 'address', 'provider', 'analysis_profile_digest', 'body_ranges'):
        if key in producer:
            require(report[key] == producer[key], 'Frozen producer ' + key + ' mismatch')


def runtime_digest(path):
    root = Path(path)
    digest = hashlib.sha256()
    paths = sorted(root.rglob('*'))
    for file in paths:
        require(not file.is_symlink(), 'Runtime tree contains a symlink')
        if file.is_file():
            name = file.relative_to(root).as_posix().encode('utf-8')
            digest.update(len(name).to_bytes(8, 'big'))
            digest.update(name)
            digest.update(hashlib.sha256(file.read_bytes()).digest())
    return digest.hexdigest()


def git_query(repository, *args):
    proc = subprocess.run(['git', '-C', repository, *args], capture_output=True, text=True, check=True)
    return proc.stdout.strip()


def check_runner(runner):
    require(git_query(runner['repository'], 'rev-parse', 'HEAD') == runner['rea_commit'], 'Runner repository HEAD mismatch')
    require(not git_query(runner['repository'], 'status', '--porcelain', '--untracked-files=no'), 'Runner tracked source is dirty')
    version = json.loads((Path(runner['repository']) / 'package.json').read_text())['version']
    require(version == runner['rea_version'], 'Runner package version mismatch')
    for item in runner['files']:
        require(sha256(Path(item['path']).read_bytes()) == item['sha256'], 'Runner executable file SHA-256 mismatch')
    require(runtime_digest(runner['runtime_tree']['path']) == runner['runtime_tree']['sha256'], 'Runner runtime tree SHA-256 mismatch')


def fresh_evidence(spec, target, output, stages):
    runner = spec['runner']
    producer = target['producers']['fresh']
    require(producer['rea_commit'] == runner['rea_commit'], 'Fresh producer commit differs from runner')
    require(producer['rea_version'] == runner['rea_version'], 'Fresh producer version differs from runner')
    check_runner(runner)
    home = output / 'home'
    temp = output / 'tmp'
    home.mkdir()
    temp.mkdir()
    environment = {'PATH':os.environ.get('PATH', ''), 'HOME':str(home), 'TMPDIR':str(temp)}
    environment.update(runner['environment'])
    snapshot = output / 'native-snapshot.json'
    require(not snapshot.exists(), 'Fresh snapshot already exists')
    command = [*runner['argv'], 'function', target['binary']['path'],
               '--procedure=' + target['address'], '--provider=ghidra',
               '--snapshot', str(snapshot), '--format', 'json', '--full-output']
    write_json(output / 'command.json', {'argv':command, 'environment':environment,
               'timeout_seconds':180, 'output_limit_bytes':16*1024*1024,
               'rlimit_as_bytes':65536*1024*1024, 'rlimit_cpu_seconds':180})
    def set_limits():
        resource.setrlimit(resource.RLIMIT_AS, (65536*1024*1024,65536*1024*1024))
        resource.setrlimit(resource.RLIMIT_CPU, (180,180))
    stdout_path = output / 'cli-stdout.json'
    stderr_path = output / 'cli-stderr.txt'
    started = time.monotonic()
    termination = None
    with stdout_path.open('wb') as stdout, stderr_path.open('wb') as stderr:
        child = subprocess.Popen(command, env=environment, stdout=stdout, stderr=stderr,
                                 start_new_session=True, preexec_fn=set_limits)
        try:
            while child.poll() is None:
                if time.monotonic() - started > 180:
                    termination = 'CLI timeout after 180 seconds'
                if stdout_path.stat().st_size + stderr_path.stat().st_size > 16*1024*1024:
                    termination = 'CLI output exceeds 16 MiB'
                if termination:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                    break
                time.sleep(0.05)
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
    stages.append({'stage':'direct_cli_function', 'elapsed_seconds':time.monotonic()-started,
                   'exit_code':child.returncode, 'termination':termination})
    check_runner(runner)
    require(not termination, termination)
    require(stdout_path.stat().st_size + stderr_path.stat().st_size <= 16*1024*1024, 'CLI output exceeds 16 MiB')
    require(child.returncode == 0, 'Direct CLI failed with exit code ' + str(child.returncode))
    envelope = json.loads(stdout_path.read_bytes())
    require(envelope.get('ok') is True, 'REA CLI returned a failure envelope')
    evidence = envelope['data']
    require(isinstance(evidence, dict) and 'normalized_result' in evidence, 'CLI did not return an Evidence object')
    return evidence


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--spec', required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--mode', required=True, choices=['fresh', 'saved'])
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output)
    require(output.is_absolute(), 'Output path must be absolute')
    if output.exists():
        require(output.is_dir(), 'Output path must be a directory')
        require(all(item.name.startswith('measurement.') and item.is_file() and not item.is_symlink() for item in output.iterdir()), 'Output directory contains prior driver artifacts')
    else:
        output.mkdir(parents=True)
    stages = []
    evidence_path = output / 'evidence.json'
    report_path = output / 'report.json'
    result = {'status':'failed', 'evidence_path':str(evidence_path), 'report_path':str(report_path), 'error':None}
    started = time.monotonic()
    try:
        spec = json.loads(Path(args.spec).read_text())
        require(spec.get('schema', spec.get('schema_version')) == 1, 'Unsupported task spec schema')
        choices = [target for target in spec['targets'] if target['id'] == args.target]
        require(len(choices) == 1, 'Target ID must select one target')
        target = choices[0]
        producer = target['producers'][args.mode]
        source = check_source(target)
        check_witness_inputs(target, source)
        stages.append({'stage':'source_and_witness_inputs', 'elapsed_seconds':time.monotonic()-started})
        if args.mode == 'fresh':
            evidence = fresh_evidence(spec, target, output, stages)
        else:
            saved = Path(target['saved_evidence']['path']).read_bytes()
            (output / 'saved-input.json').write_bytes(saved)
            require(sha256(saved) == target['saved_evidence']['sha256'], 'Saved evidence file SHA-256 mismatch')
            evidence = json.loads(saved)
            require('normalized_result' in evidence, 'Saved input must be exact REA Evidence object')
        write_json(evidence_path, evidence)
        report = check_evidence(evidence, target, source)
        producer_checks(report, producer)
        report.update({'producer':producer, 'mode':args.mode})
        source_after = check_source(target)
        require(source_after == source, 'Source changed during task')
        check_witness_inputs(target, source_after)
        if args.mode == 'saved':
            require(sha256(Path(target['saved_evidence']['path']).read_bytes()) == target['saved_evidence']['sha256'], 'Saved input changed during task')
        write_json(report_path, report)
        result.update({'status':'ok'})
    except Exception as exc:
        result['error'] = type(exc).__name__ + ': ' + str(exc)
        write_json(output / 'failure.json', {'error':result['error']})
    finally:
        stages.append({'stage':'driver_total', 'elapsed_seconds':time.monotonic()-started})
        write_json(output / 'stages.json', stages)
        result['stages'] = stages
        write_json(output / 'result.json', result)
    return 0 if result['status'] == 'ok' else 1


if __name__ == '__main__':
    sys.exit(main())
