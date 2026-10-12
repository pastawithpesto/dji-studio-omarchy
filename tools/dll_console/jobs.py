"""Durable fixed-model queue; controls apply only to this console's processes."""
import datetime
import fcntl
import json
import os
import re
from pathlib import Path
import signal
import subprocess
import threading
import time
import uuid
from data import MODELS, alive, load_json, start_ticks, workers


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def command(model_key, output, session=None):
    model = MODELS[model_key]
    if model['backend'] == 'codex':
        args = ['codex', 'exec']
        if session:
            args += ['resume', session]
        args += ['--skip-git-repo-check', '--json', '-m', model['model'],
                 '-c', 'model_reasoning_effort="high"', '-c', 'service_tier="default"',
                 '-c', 'features.fast_mode=false', '-c', 'approval_policy="never"',
                 '-c', 'sandbox_mode="workspace-write"', '-o', str(output / 'FINAL.txt'), '-']
        return args
    args = [str(Path.home() / '.local/bin/opencode'), 'run', '--standalone', '--model', model['model'],
            '--agent', 'dll-research', '--format', 'json', '--auto']
    if session:
        args += ['--session', session]
    return args


class Queue:
    LIMIT = 3

    def __init__(self, project, runtime, catalog, launch=True):
        self.project, self.runtime, self.catalog = Path(project).resolve(), Path(runtime).resolve(), catalog
        self.control = self.runtime / 'control'
        self.output = self.runtime / 'artifacts'
        self.control.mkdir(parents=True, exist_ok=True)
        self.output.mkdir(parents=True, exist_ok=True)
        self.lock = threading.RLock()
        self.jobs = {p.stem: load_json(p) for p in self.control.glob('*.json')}
        self.jobs = {k: v for k, v in self.jobs.items() if isinstance(v, dict) and v.get('id') == k and re.fullmatch(r'[0-9a-f]{32}', k) and v.get('model') in MODELS and v.get('status') in ('queued', 'running', 'paused', 'failed', 'interrupted', 'completed') and v.get('action') in ('research', 'review') and isinstance(v.get('parts'), list) and isinstance(v.get('created_at'), str) and isinstance(v.get('dll'), str)}
        self.processes = {}
        self.offsets = {}
        self.closed = False
        if launch:
            self.thread = threading.Thread(target=self.loop, daemon=True)
            self.thread.start()

    def save(self, job):
        job['updated_at'] = utc()
        path = self.control / (job['id'] + '.json')
        temp = path.with_suffix('.tmp')
        temp.write_text(json.dumps(job, indent=2) + '\n')
        temp.replace(path)

    def snapshot(self):
        with self.lock:
            result = []
            for job in sorted(self.jobs.values(), key=lambda j: j['created_at'], reverse=True):
                public = {k: v for k, v in job.items() if k not in ('log', 'start_ticks', 'reported_error', 'turn_completed')}
                public['owned'] = True
                root = self.output / job['id']
                public['artifacts'] = [dict(label=name, url=f"/api/jobs/{job['id']}/artifact/{name}") for name in ('FINAL.txt', 'REPORT.md', 'CONTRACT.json', 'REVIEW.md', 'REVIEW.json', 'MANIFEST.json', 'PROGRESS.json') if (root / name).is_file() and (root / name).resolve().is_relative_to(root.resolve())]
                result.append(public)
            return result

    def external_blocker(self, dll, parts, action):
        if action != 'research' or dll != 'ThumbnailProvider.dll':
            return None
        internal = any(p['id'] != 'exports-and-create-helper' and not p['id'].startswith('export:') for p in parts)
        if not internal:
            return None
        state = load_json(self.project / 'reconstruction/kimi-thumbnailprovider-20261012/DISPATCH.json', {})
        if state.get('state') == 'waiting_for_cli_slot' or (state.get('state') == 'launched' and alive(state.get('pid', 0))):
            return 'Kimi already owns the remaining ThumbnailProvider internals. This task waits for that handoff.'
        return None

    def preview(self, request, output=None):
        if not isinstance(request, dict):
            raise ValueError('Expected a task object')
        model = request.get('model')
        action = request.get('action')
        notes = request.get('notes', '')
        if model not in MODELS or action not in ('research', 'review'):
            raise ValueError('Choose a supported model and research or review action')
        if not isinstance(notes, str) or len(notes) > 8000:
            raise ValueError('Directions must be text of at most 8000 characters')
        module = self.catalog.module(request.get('dll'))
        parts = self.catalog.selections(module, request.get('parts'))
        selected = '\n'.join('- ' + p['label'] + ': ' + p.get('detail', '') +
                             '\n  Addresses: ' + ', '.join(p.get('addresses', [])) +
                             '\n  Missing: ' + '; '.join(p.get('missing', [])) +
                             '\n  Evidence: ' + ', '.join(e['path'] for e in p.get('evidence', [])) for p in parts)
        destination = str(output) if output else '[isolated console job output directory]'
        prompt = f'''User-requested DLL console task. Action: {action}.
Original DLL: {module['path']}; SHA256 {module['sha256']}.
Project: {self.project}. Write only to {destination}.
Selected bounded work:
{selected}

Read project AGENTS.md and the relevant immutable evidence. Coordinator records
the current source identity in SOURCE.json before launch. Preserve vendor bytes,
peer scopes, existing sessions and all original reports. Existing evidence retains
its producing tool version. Use only original bytes and saved matching analysis;
no new REA session/import, installation, vendor execution or native application
checks in this initial task. No application source changes, push, merge, release,
additional model workers or peer process actions. Treat every missing name, unit,
dynamic boundary and reference result as unresolved until established by evidence.
For review, keep the author/reviewer roles separate and do not approve broader
behavior than the exact pinned candidate supports. Write REPORT.md, CONTRACT.json
or REVIEW.json as applicable, source/input byte pins and MANIFEST.json in your output
folder. Distinguish static evidence, implementation and original-reference parity.
Write RECEIPT.json in your output folder after reading this actual task. Include
the task id, selected scope and what you actually read. Update PROGRESS.json with
public findings and limits at packet boundaries. Do not put private reasoning,
credentials or API keys in artifacts. No model/provider fallback is authorized.

User directions:
{notes or '(No additional directions)'}
'''
        return dict(prompt=prompt, scope_blocker=self.external_blocker(module['id'], parts, action),
                    selection_summary=', '.join(p['label'] for p in parts)), module, parts

    def enqueue(self, request):
        preview, module, parts = self.preview(request)
        with self.lock:
            for old in self.jobs.values():
                if old['status'] in ('queued', 'running') and old['dll'] == module['id'] and old['action'] == request['action'] and set(old['parts']) & set(request['parts']):
                    raise ValueError('An active console task already owns this selection')
            ident = uuid.uuid4().hex
            out = self.output / ident
            out.mkdir()
            job = dict(id=ident, dll=module['id'], parts=[p['id'] for p in parts], model=request['model'], action=request['action'],
                       status='queued', owned=True, created_at=utc(), updated_at=utc(), summary=preview['selection_summary'],
                       notes=request.get('notes', ''), reason=preview['scope_blocker'] or 'Waiting for a CLI slot', usage={}, attempt=0)
            (out / 'TASK.txt').write_text(self.preview(request, out)[0]['prompt'] + f'\nTask id: {ident}\n')
            self.jobs[ident] = job
            self.save(job)
            return next(j for j in self.snapshot() if j['id'] == job['id'])

    def owned_process(self, job):
        try:
            return bool(job.get('pid') and job.get('start_ticks') and alive(job['pid'], job['start_ticks']) and os.getpgid(job['pid']) == job['pid'] and Path(f"/proc/{job['pid']}/cwd").resolve() == self.output / job['id'])
        except (OSError, ValueError):
            return False

    def group_alive(self, job):
        if not job.get('pid'):
            return False
        for path in Path('/proc').iterdir():
            if not path.name.isdigit():
                continue
            try:
                fields = (path / 'stat').read_text().rsplit(')', 1)[1].split()
                if fields[0] != 'Z' and fields[2] == str(job['pid']) and fields[3] == str(job['pid']):
                    return True
            except (OSError, IndexError):
                continue
        return False

    def pause(self, ident):
        with self.lock:
            if ident not in self.jobs:
                raise ValueError('Unknown console job')
            job = self.jobs[ident]
            if job['status'] not in ('queued', 'running'):
                raise ValueError('This job is not active')
            if job['status'] == 'running':
                if not self.owned_process(job):
                    raise ValueError('Owned process identity no longer matches; no signal sent')
                os.killpg(job['pid'], signal.SIGTERM)
            job.update(status='paused', reason='Paused by user; artifacts preserved')
            self.save(job)
            return next(j for j in self.snapshot() if j['id'] == job['id'])

    def resume(self, ident):
        with self.lock:
            if ident not in self.jobs:
                raise ValueError('Unknown console job')
            job = self.jobs[ident]
            if job['status'] not in ('paused', 'failed', 'interrupted') or self.group_alive(job):
                raise ValueError('Only a stopped paused or failed job can be resumed')
            for old in self.jobs.values():
                if old['id'] != ident and old['status'] in ('queued', 'running') and old['dll'] == job['dll'] and old['action'] == job['action'] and set(old['parts']) & set(job['parts']):
                    raise ValueError('Another active task owns this selection')
            job.update(status='queued', reason='Resume requested on the same model')
            self.save(job)
            return next(j for j in self.snapshot() if j['id'] == job['id'])

    def source_identity(self, output):
        repo = self.project / 'native'
        def git(*args):
            return subprocess.check_output(['git', '-C', str(repo), *args], text=True, timeout=30).strip()
        try:
            subprocess.run(['git', '-C', str(repo), 'fetch', 'origin', 'main'], capture_output=True, timeout=30, check=True)
            record = dict(checked_at=utc(), head=git('rev-parse', 'HEAD'), fresh_main=git('rev-parse', 'origin/main'), branch=git('branch', '--show-current'), status=git('status', '--short'), verified=True)
        except (OSError, subprocess.SubprocessError):
            record = dict(checked_at=utc(), verified=False, reason='Fresh source check failed; do not claim a verified base')
        (output / 'SOURCE.json').write_text(json.dumps(record, indent=2) + '\n')
        return record

    def launch(self, job):
        output = self.output / job['id']
        if not self.source_identity(output)['verified']:
            job.update(status='failed', reason='Fresh source check failed before launch')
            self.save(job)
            return
        if MODELS[job['model']]['backend'] == 'opencode':
            folder = output / '.opencode'
            folder.mkdir(exist_ok=True)
            cfg = {'agents': {'dll-research': {'mode': 'primary', 'description': 'Console-assigned bounded DLL research', 'system': 'Follow TASK.txt. Write only to this task folder. Preserve original bytes and peers. Never install, run vendor code, alter application source, launch another model or inspect credentials.'}}, 'providers': {'nvidia': {'models': {'moonshotai/kimi-k3': {'settings': {'reasoningEffort': 'high'}}}}}}
            (folder / 'opencode.json').write_text(json.dumps(cfg, indent=2) + '\n')
        args = command(job['model'], output, job.get('session'))
        job['attempt'] += 1
        logs = self.runtime / 'logs'
        logs.mkdir(exist_ok=True)
        log = logs / (job['id'] + '-' + str(job['attempt']) + '.jsonl')
        err = log.with_suffix('.stderr')
        prompt = (output / 'TASK.txt').read_bytes()
        if job['attempt'] > 1:
            prompt += b'\nResume only unfinished work. Read existing artifacts and preserve them.\n'
        self.offsets[job['id']] = 0
        job.pop('reported_error', None)
        job.pop('turn_completed', None)
        job['usage'] = {}
        try:
            with log.open('wb') as stream, err.open('wb') as errors:
                if MODELS[job['model']]['backend'] == 'opencode':
                    args.append(prompt.decode())
                    proc = subprocess.Popen(args, cwd=output, stdin=subprocess.DEVNULL, stdout=stream, stderr=errors, start_new_session=True)
                else:
                    proc = subprocess.Popen(args, cwd=output, stdin=subprocess.PIPE, stdout=stream, stderr=errors, start_new_session=True)
                self.processes[job['id']] = proc
                job.update(status='running', reason='CLI started; waiting for actual worker receipt', pid=proc.pid, start_ticks=start_ticks(proc.pid), log=str(log), receipt=False)
                self.save(job)
                if proc.stdin:
                    try:
                        proc.stdin.write(prompt)
                        proc.stdin.close()
                    except BrokenPipeError:
                        pass
        except OSError:
            job.update(status='failed', reason='CLI could not start; no automatic retry or model fallback')
            self.save(job)

    def read_events(self, job):
        path = Path(job.get('log', ''))
        if not path.is_file():
            return
        offset = self.offsets.get(job['id'], 0)
        with path.open('rb') as stream:
            stream.seek(offset)
            for _ in range(200):
                begin = stream.tell()
                line = stream.readline(1_000_001)
                if not line:
                    break
                if len(line) > 1_000_000:
                    while line and not line.endswith(b'\n'):
                        line = stream.readline(1_000_001)
                    self.offsets[job['id']] = stream.tell()
                    continue
                if not line.endswith(b'\n'):
                    self.offsets[job['id']] = begin
                    break
                self.offsets[job['id']] = stream.tell()
                try:
                    item = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(item, dict):
                    continue
                session = item.get('thread_id') if item.get('type') == 'thread.started' else item.get('sessionID')
                if isinstance(session, str) and re.fullmatch(r'(?:[0-9a-fA-F-]{36}|ses_[a-zA-Z0-9]+)', session):
                    job['session'] = session
                if item.get('type') == 'turn.completed':
                    usage = item.get('usage', {})
                    job['usage'] = {k: v for k, v in usage.items() if k in ('input_tokens', 'output_tokens', 'cached_input_tokens') and isinstance(v, int) and v >= 0} if isinstance(usage, dict) else {}
                    job['turn_completed'] = True
                if item.get('type') == 'step_finish' and isinstance(item.get('part'), dict):
                    part = item['part']
                    if part.get('reason') == 'stop':
                        job['turn_completed'] = True
                    tokens = part.get('tokens', {})
                    if isinstance(tokens, dict):
                        for dest, key in [('input_tokens', 'input'), ('output_tokens', 'output')]:
                            if isinstance(tokens.get(key), int) and tokens[key] >= 0:
                                job['usage'][dest] = job['usage'].get(dest, 0) + tokens[key]
                if item.get('type') in ('error', 'turn.failed'):
                    job['reported_error'] = True
        receipt = load_json(self.output / job['id'] / 'RECEIPT.json')
        if isinstance(receipt, dict) and receipt.get('task_id', receipt.get('id')) == job['id']:
            job['receipt'] = True
            job['reason'] = 'Worker receipt recorded; scoped task is running'
        progress = load_json(self.output / job['id'] / 'PROGRESS.json')
        if isinstance(progress, dict) and isinstance(progress.get('summary'), str):
            job['progress'] = progress['summary'][:1200]

    def tick(self):
        with self.lock:
            for job in self.jobs.values():
                if job['status'] in ('running', 'paused'):
                    self.read_events(job)
                    proc = self.processes.get(job['id'])
                    code = proc.poll() if proc else None
                    if job['status'] == 'paused':
                        continue
                    if not self.owned_process(job) and not self.group_alive(job):
                        if code == 0 and not job.get('reported_error') and job.get('turn_completed'):
                            job.update(status='completed', reason='CLI turn completed; evidence still needs independent review')
                        elif code is not None:
                            job.update(status='failed', reason='CLI/provider failure; no model fallback or automatic retry')
                        else:
                            job.update(status='interrupted', reason='Process ended without a verified turn result')
                        self.save(job)
                    else:
                        self.save(job)
            for job in self.jobs.values():
                if job['status'] != 'queued':
                    continue
                preview = self.preview(dict(dll=job['dll'], parts=job['parts'], model=job['model'], action=job['action'], notes=job.get('notes', '')))[0]
                if preview['scope_blocker']:
                    job['reason'] = preview['scope_blocker']
                    self.save(job)
                    continue
                lock_file = self.project / 'coordination/model-launch.lock'
                lock_file.parent.mkdir(parents=True, exist_ok=True)
                with lock_file.open('a') as stream:
                    fcntl.flock(stream, fcntl.LOCK_EX)
                    if len(workers()) >= self.LIMIT:
                        job['reason'] = 'Waiting for a free CLI slot; existing workers preserved'
                        self.save(job)
                        break
                    self.launch(job)

    def loop(self):
        while not self.closed:
            try:
                self.tick()
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                with self.lock:
                    for job in self.jobs.values():
                        if job['status'] == 'queued':
                            job['reason'] = 'Dispatch could not proceed: ' + type(error).__name__
                            self.save(job)
            time.sleep(2)
