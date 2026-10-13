#!/usr/bin/env python3
"""Common external benchmark monitor. It does not implement either workflow."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import resource
import re
import signal
import struct
import subprocess
import time

PAGE = os.sysconf('SC_PAGE_SIZE')
OBSERVED_PIDS = {os.getpid()}

def read_processes():
    result = {}
    pending = list(OBSERVED_PIDS)
    visited = set()
    while pending:
        pid = pending.pop()
        if pid in visited:
            continue
        visited.add(pid)
        path = Path('/proc') / str(pid)
        try:
            text = (path / 'stat').read_text()
            fields = text[text.rfind(')') + 2:].split()
            result[int(path.name)] = {'ppid': int(fields[1]), 'start': fields[19],
                                     'state': fields[0], 'rss': int(fields[21]) * PAGE}
            for task in (path / 'task').iterdir():
                try:
                    pending.extend(int(child) for child in (task / 'children').read_text().split())
                except (OSError, ValueError):
                    pass
        except (OSError, ValueError, IndexError):
            pass
    OBSERVED_PIDS.update(result)
    return result

def track_owned(table, owned):
    parents = {os.getpid()} | {pid for pid, start in owned.items()
                              if pid in table and table[pid]['start'] == start}
    changed = True
    while changed:
        changed = False
        for pid, row in table.items():
            if pid != os.getpid() and row['ppid'] in parents and pid not in parents:
                owned[pid] = row['start']
                parents.add(pid)
                changed = True

def living(owned, table):
    return [pid for pid, start in owned.items() if pid in table and
            table[pid]['start'] == start and table[pid]['state'] != 'Z']

def signal_owned(owned, sig):
    table = read_processes()
    for pid in living(owned, table):
        try:
            os.kill(pid, sig)
        except ProcessLookupError:
            pass

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def evidence_object(value):
    if isinstance(value, dict) and 'operation' in value:
        return value
    if isinstance(value, dict) and value.get('ok') is True:
        return evidence_object(value.get('data'))
    if isinstance(value, dict) and isinstance(value.get('structuredContent'), dict):
        return evidence_object(value['structuredContent'])
    raise ValueError('Unsupported evidence envelope')

def original_pe_offset(source, address, length):
    if source[:2] != b'MZ':
        raise ValueError('Original is not PE')
    pe = struct.unpack_from('<I', source, 0x3c)[0]
    if source[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Invalid PE signature')
    sections = struct.unpack_from('<H', source, pe + 6)[0]
    optional_size = struct.unpack_from('<H', source, pe + 20)[0]
    optional = pe + 24
    if struct.unpack_from('<H', source, optional)[0] != 0x20b:
        raise ValueError('Expected pinned PE32+ target')
    image_base = struct.unpack_from('<Q', source, optional + 24)[0]
    rva = address - image_base
    matches = []
    for index in range(sections):
        base = optional + optional_size + index * 40
        _, virtual_address, raw_size, raw_offset = struct.unpack_from('<IIII', source, base + 8)
        if virtual_address <= rva and rva + length <= virtual_address + raw_size:
            matches.append(raw_offset + rva - virtual_address)
    if len(matches) != 1 or matches[0] + length > len(source):
        raise ValueError('No unique complete original-file mapping')
    return matches[0]

def verify(spec, target, mode, output):
    result = json.loads((output / 'result.json').read_text())
    if result.get('status') != 'ok':
        raise ValueError('Worker failed: ' + str(result.get('error')))
    ep = Path(result['evidence_path'])
    rp = Path(result['report_path'])
    if not ep.resolve().is_relative_to(output.resolve()) or not rp.resolve().is_relative_to(output.resolve()):
        raise ValueError('Worker artifacts are outside its trial')
    evidence = evidence_object(json.loads(ep.read_text()))
    report = json.loads(rp.read_text())
    source = Path(target['binary']['path']).read_bytes()
    if hashlib.sha256(source).hexdigest() != target['binary']['sha256']:
        raise ValueError('Original source hash changed')
    if evidence['subject']['digest']['sha256'] != target['binary']['sha256']:
        raise ValueError('Evidence source mismatch')
    producer = target['producers'][mode]
    if evidence['provider'] != producer['provider'] or evidence['analysis_profile']['digest'] != producer['analysis_profile_digest']:
        raise ValueError('Provider or profile mismatch')
    if evidence['analysis_profile']['provider'] != producer['provider']:
        raise ValueError('Profile provider mismatch')
    if evidence['operation'] != 'analyze_function' or evidence['parameters'] != {'procedure': target['address']}:
        raise ValueError('Operation mismatch')
    normalized = evidence['normalized_result']
    procedure = normalized['procedure']
    pseudo = normalized['pseudocode']
    assembly = normalized['assembly']
    if procedure['address'] != target['address'] or not isinstance(pseudo, str) or not pseudo.strip() or not isinstance(assembly, list) or not assembly or any(not isinstance(row, str) or not row.strip() for row in assembly):
        raise ValueError('Missing function output')
    if re.search(r'halt_baddata|BAD_DATA|decompilation failed|unable to decompile', pseudo, re.IGNORECASE):
        raise ValueError('Failed decompilation marker')
    if procedure['body'].get('available') is not True or procedure['body'].get('contains_entry') is not True:
        raise ValueError('Function body unavailable or entry outside body')
    if procedure['body']['ranges'] != target['body_ranges']:
        raise ValueError('Changed function body ranges')
    total = 0
    for witness in target['byte_witnesses']:
        raw = bytes.fromhex(witness['hex'])
        offset = witness['file_offset']
        if original_pe_offset(source, int(witness['address'], 16), len(raw)) != offset:
            raise ValueError('Supplied PE address mapping mismatch')
        if source[offset:offset + len(raw)] != raw:
            raise ValueError('Original body bytes changed')
        total += len(raw)
    if total != procedure['body']['total_bytes']:
        raise ValueError('Incomplete body witness')
    expected = {'source_sha256': target['binary']['sha256'], 'address': target['address'],
                'provider': evidence['provider'], 'analysis_profile_digest': evidence['analysis_profile']['digest'],
                'pseudocode': normalized['pseudocode'], 'assembly': normalized['assembly'],
                'body_ranges': procedure['body']['ranges'], 'witness_bytes': total,
                'source_byte_match': True, 'producer': producer, 'mode': mode}
    for key, value in expected.items():
        if report.get(key) != value:
            raise ValueError('Worker report mismatch: ' + key)
    limitations = report.get('limitations')
    if not isinstance(limitations, list) or any(x not in limitations for x in evidence.get('limitations', [])) or any(x not in limitations for x in normalized.get('limitations', [])):
        raise ValueError('Worker dropped raw limitations')
    if mode == 'saved':
        saved = target['saved_evidence']
        if sha(saved['path']) != saved['sha256'] or evidence != evidence_object(json.loads(Path(saved['path']).read_text())):
            raise ValueError('Saved evidence changed')
    canonical = json.dumps(evidence, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()
    return {'evidence_sha256': hashlib.sha256(canonical).hexdigest(), 'raw_evidence_sha256': sha(ep),
            'report_sha256': sha(rp), 'evidence_id': evidence['evidence_id'], 'witness_bytes': total,
            'stages': result.get('stages', report.get('stages', {}))}

def measure(spec, target, mode, side, driver, output):
    output.mkdir(parents=True, exist_ok=False)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'Cannot set child subreaper')
    command = [spec['python'], driver, '--spec', spec['spec_path'], '--target', target['id'],
               '--mode', mode, '--output', str(output)]
    record = {'side': side, 'mode': mode, 'target': target['id'], 'command': command,
              'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'sample_interval_seconds': .02, 'memory_scope': 'monitor plus all observed owned descendants'}
    owned = {}
    user = system = 0.0
    max_rss = peak_total = peak_desc = 0
    samples = 0
    heaps = set()
    errors = []
    parent_before = resource.getrusage(resource.RUSAGE_SELF)
    start = time.perf_counter()
    main_status = None
    with (output / 'measurement.stdout').open('wb') as stdout, (output / 'measurement.stderr').open('wb') as stderr:
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr, start_new_session=True,
                                   env={'PATH': os.environ['PATH'], 'PYTHONDONTWRITEBYTECODE': '1'})
        main_pid = process.pid
        while main_status is None:
            table = read_processes()
            track_owned(table, owned)
            descendant_rss = sum(table[pid]['rss'] for pid, stamp in owned.items()
                                 if pid in table and table[pid]['start'] == stamp)
            parent_rss = table.get(os.getpid(), {}).get('rss', 0)
            peak_total = max(peak_total, descendant_rss + parent_rss)
            peak_desc = max(peak_desc, descendant_rss)
            samples += 1
            for pid in owned:
                try:
                    argv = (Path('/proc') / str(pid) / 'cmdline').read_bytes().split(b'\0')
                    if argv and argv[0].endswith(b'/java'):
                        heaps.update(x.decode() for x in argv if x.startswith(b'-Xmx'))
                except OSError:
                    pass
            elapsed = time.perf_counter() - start
            if elapsed > spec['limits']['pipeline_timeout_seconds'] or peak_total > spec['limits']['aggregate_rss_bytes']:
                errors.append('Pipeline deadline' if elapsed > spec['limits']['pipeline_timeout_seconds'] else 'Sampled aggregate RSS limit')
                signal_owned(owned, signal.SIGTERM)
                time.sleep(.3)
                signal_owned(owned, signal.SIGKILL)
            try:
                pid, status, usage = os.wait4(-1, os.WNOHANG)
            except ChildProcessError:
                if main_status is None:
                    raise RuntimeError('Main worker status was lost')
                break
            if pid:
                user += usage.ru_utime
                system += usage.ru_stime
                max_rss = max(max_rss, usage.ru_maxrss)
                if pid == main_pid:
                    main_status = status
            else:
                time.sleep(.02)
        cleanup_start = time.perf_counter()
        table = read_processes()
        track_owned(table, owned)
        if living(owned, table):
            signal_owned(owned, signal.SIGTERM)
        while time.perf_counter() - cleanup_start < 1.0:
            table = read_processes()
            track_owned(table, owned)
            if not living(owned, table):
                break
            time.sleep(.02)
        signal_owned(owned, signal.SIGKILL)
        deadline = time.perf_counter() + 2.0
        while time.perf_counter() < deadline:
            try:
                pid, status, usage = os.wait4(-1, os.WNOHANG)
            except ChildProcessError:
                break
            if pid:
                user += usage.ru_utime
                system += usage.ru_stime
                max_rss = max(max_rss, usage.ru_maxrss)
            else:
                time.sleep(.02)
        table = read_processes()
        survivors = living(owned, table)
        if survivors:
            errors.append('Owned processes survived cleanup')
        record['cleanup_seconds'] = time.perf_counter() - cleanup_start
        record['surviving_processes'] = survivors
        return_code = os.waitstatus_to_exitcode(main_status)
        process.returncode = return_code
        record['returncode'] = return_code
        check_cpu_before = resource.getrusage(resource.RUSAGE_SELF)
        try:
            if return_code != 0:
                raise ValueError('Worker process exit ' + str(return_code))
            record['verification'] = verify(spec, target, mode, output)
        except Exception as exc:
            errors.append(str(exc))
        check_cpu_after = resource.getrusage(resource.RUSAGE_SELF)
        table = read_processes()
        peak_total = max(peak_total, table.get(os.getpid(), {}).get('rss', 0))
    parent_after = resource.getrusage(resource.RUSAGE_SELF)
    record.update({'wall_seconds': time.perf_counter() - start,
                   'cpu_user_seconds': user + parent_after.ru_utime - parent_before.ru_utime,
                   'cpu_system_seconds': system + parent_after.ru_stime - parent_before.ru_stime,
                   'wait4_max_process_rss_kib': max_rss, 'peak_sampled_aggregate_rss_bytes': peak_total,
                   'peak_sampled_descendant_rss_bytes': peak_desc, 'memory_samples': samples,
                   'java_heap_arguments': sorted(heaps), 'errors': errors,
                   'finished_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())})
    record['cpu_workflow_user_seconds'] = user + check_cpu_after.ru_utime - check_cpu_before.ru_utime
    record['cpu_workflow_system_seconds'] = system + check_cpu_after.ru_stime - check_cpu_before.ru_stime
    record['cpu_monitor_user_seconds'] = record['cpu_user_seconds'] - record['cpu_workflow_user_seconds']
    record['cpu_monitor_system_seconds'] = record['cpu_system_seconds'] - record['cpu_workflow_system_seconds']
    (output / 'measurement.json').write_text(json.dumps(record, indent=2) + '\n')
    return record

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--spec', required=True)
    p.add_argument('--target', required=True)
    p.add_argument('--mode', choices=['fresh', 'saved'], required=True)
    p.add_argument('--side', choices=['queue', 'manual'], required=True)
    p.add_argument('--driver', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()
    spec = json.loads(Path(args.spec).read_text())
    spec['spec_path'] = str(Path(args.spec).resolve())
    target = next(t for t in spec['targets'] if t['id'] == args.target)
    result = measure(spec, target, args.mode, args.side, args.driver, Path(args.output))
    print(json.dumps({k: result[k] for k in ['side', 'mode', 'target', 'wall_seconds', 'errors']}))
