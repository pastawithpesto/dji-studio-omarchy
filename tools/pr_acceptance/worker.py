#!/usr/bin/env python3
"""Local, opt-in PR acceptance. Independent operational design, no PR code execution."""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import random
import re
import signal
import subprocess
import time
import uuid

from claims import inspect

REPO = 'pastawithpesto/dji-studio-omarchy'
OWNER = {'login': 'pastawithpesto', 'id': 23729105}
AUTHOR = {'login': 'revmnds', 'id': 278795669}
GH = '/home/violence/.local/share/mise/installs/gh/latest/gh_2.102.0_linux_amd64/bin/gh'
CLAIMS_SHA = 'a82816161fa1ae5afe92de9a8302ee394ee9d36105aa9b0454308a3f8b773f30'
MAX_CALLS = 128
MAX_SECONDS = 180
SHA = re.compile(r'[0-9a-f]{40}')


class Unavailable(Exception):
    def __init__(self, message, retry_after=0, http_status=None, mutation=False):
        super().__init__(message)
        self.retry_after = retry_after
        self.http_status = http_status
        self.mutation = mutation


class NotReady(Unavailable):
    """A complete observation of an unmet gate; other candidates may be checked."""


def gate(condition, message):
    if not condition:
        raise NotReady(message)


def require(condition, message):
    if not condition:
        raise Unavailable(message)


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha(value):
    require(isinstance(value, str) and SHA.fullmatch(value), 'Invalid commit identity')
    return value


def user(value, expected):
    return isinstance(value, dict) and type(value.get('id')) is int and all(value.get(k) == v for k, v in expected.items())


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def atomic(path, value):
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    with temp.open('x') as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)


class GitHub:
    def __init__(self, apply=False):
        self.apply = apply
        self.calls = 0
        self.started = time.monotonic()
        self.records = []

    def request(self, path, payload=None):
        require(path == '' or (path.startswith('/') and not path.startswith('//')), 'Invalid endpoint')
        require(self.calls < MAX_CALLS and time.monotonic() - self.started < MAX_SECONDS, 'Cycle API budget exhausted')
        require(payload is None or self.apply, 'Mutation disabled in dry-run')
        if payload is not None:
            require(re.fullmatch(r'/pulls/[1-9][0-9]*/merge', path) and set(payload) == {'sha', 'merge_method'} and payload['merge_method'] == 'merge', 'Only expected-head merge is permitted')
            sha(payload['sha'])
        self.calls += 1
        argv = [GH, 'api', '--hostname', 'github.com', '--method', 'GET' if payload is None else 'PUT',
                '--include', '-H', 'Accept: application/vnd.github+json', '-H', 'X-GitHub-Api-Version: 2026-03-10',
                'repos/' + REPO + path]
        if payload is not None:
            argv += ['--input', '-']
        env = dict(os.environ, GH_PROMPT_DISABLED='1', GH_PAGER='cat')
        env.pop('GH_DEBUG', None)
        try:
            result = subprocess.run(argv, input=json.dumps(payload) if payload is not None else '',
                                    capture_output=True, text=True, timeout=25, env=env)
        except subprocess.TimeoutExpired:
            self.records.append({'path': path, 'method': 'GET' if payload is None else 'PUT', 'status': 'timeout'})
            raise Unavailable('GitHub request timed out') from None
        header, separator, body = result.stdout.replace('\r\n', '\n').partition('\n\n')
        match = re.match(r'HTTP/\S+ (\d+)', header)
        status = int(match[1]) if match else 0
        headers = dict((k.lower(), v.strip()) for line in header.splitlines()[1:] if ':' in line for k, v in [line.split(':', 1)])
        retry = 0
        try:
            retry = max(0, int(headers.get('retry-after', 0)))
            if headers.get('x-ratelimit-remaining') == '0':
                retry = max(retry, int(headers.get('x-ratelimit-reset', 0)) - time.time() + 1)
        except ValueError:
            pass
        self.records.append({'path': path, 'method': 'GET' if payload is None else 'PUT', 'status': status})
        require(separator, 'Missing GitHub response headers')
        if status != 200 or result.returncode:
            raise Unavailable('GitHub HTTP failure', retry, status, payload is not None)
        try:
            return json.loads(body)
        except ValueError:
            raise Unavailable('Invalid GitHub JSON') from None

    def get(self, path):
        return self.request(path)

    def merge(self, number, head):
        require(type(number) is int and number > 0, 'Invalid PR number')
        return self.request(f'/pulls/{number}/merge', {'sha': sha(head), 'merge_method': 'merge'})

    def pages(self, path, limit, key=None):
        output = []
        expected = None
        for page in range(1, limit + 1):
            value = self.get(path + ('&' if '?' in path else '?') + f'per_page=100&page={page}')
            if key:
                require(isinstance(value, dict) and type(value.get('total_count')) is int and value['total_count'] >= 0, 'Missing paginated count')
                count = value['total_count']
                require(expected is None or expected == count, 'Paginated count changed')
                expected = count
                values = value.get(key)
            else:
                values = value
            require(isinstance(values, list) and len(values) <= 100, 'Invalid API page')
            output.extend(values)
            if len(values) < 100:
                require(expected is None or len(output) == expected, 'Incomplete counted inventory')
                return output
        raise Unavailable('Pagination limit reached')


def unique(items, key):
    values = [item[key] for item in items]
    require(len(values) == len(set(values)), 'Duplicate inventory entries')


def pr_identity(pr):
    def ref(value):
        return {k: value[k] for k in ('sha', 'ref')} | {'repo': {k: value['repo'][k] for k in ('id', 'full_name')}}
    return {k: pr[k] for k in ('number', 'body', 'draft', 'state')} | {
        'user': {k: pr['user'][k] for k in ('id', 'login')}, 'head': ref(pr['head']), 'base': ref(pr['base'])}


def world(api):
    listing = api.pages('/pulls?state=open&sort=created&direction=asc', 5)
    unique(listing, 'number')
    prs, files = {}, {}
    for listed in listing:
        number = listed['number']
        require(type(number) is int and number > 0, 'Invalid listed PR number')
        detail = api.get(f'/pulls/{number}')
        require(pr_identity(detail) == pr_identity(listed) and detail['state'] == 'open', 'PR changed during collection')
        changed = api.pages(f'/pulls/{number}/files', 30)
        unique(changed, 'filename')
        require(all(isinstance(f['filename'], str) and f['filename'] and f.get('status') in {'added', 'removed', 'modified', 'renamed', 'copied', 'changed', 'unchanged'} for f in changed), 'Invalid changed-file records')
        require(all(f.get('status') != 'renamed' or isinstance(f.get('previous_filename'), str) and f['previous_filename'] for f in changed), 'Missing rename origin')
        require(type(detail.get('changed_files')) is int and detail['changed_files'] == len(changed), 'Incomplete changed files')
        after = api.get(f'/pulls/{number}')
        require(pr_identity(after) == pr_identity(detail) and after['changed_files'] == len(changed), 'PR/file inventory race')
        prs[str(number)], files[str(number)] = detail, changed
    claims, errors = inspect(list(prs.values()), lambda n: prs[str(n)], lambda n: files[str(n)])
    require(not errors, 'Open PR claim conflict or coverage error')
    end = api.pages('/pulls?state=open&sort=created&direction=asc', 5)
    unique(end, 'number')
    require({str(p['number']): pr_identity(p) for p in end} == {n: pr_identity(p) for n, p in prs.items()}, 'Open PR membership/identity race')
    # Patch hunks are data and are not needed in the durable comparison.
    return {'prs': prs, 'files': {n: [{k: f[k] for k in ('filename', 'status', 'previous_filename') if k in f} for f in v] for n, v in files.items()}, 'claims': claims}


def reviews_allow(reviews, head):
    unique(reviews, 'id')
    latest = {}
    for review in reviews:
        require(type(review['id']) is int and review['id'] > 0, 'Invalid review ID')
        state = review['state']
        require(state in {'APPROVED', 'CHANGES_REQUESTED', 'COMMENTED', 'DISMISSED', 'PENDING'}, 'Unknown review state')
        gate(state != 'PENDING', 'Pending review is ambiguous')
        reviewer = review['user']
        require(type(reviewer['id']) is int and reviewer['id'] > 0 and isinstance(reviewer['login'], str), 'Invalid reviewer identity')
        if state in {'COMMENTED', 'DISMISSED'}:
            continue
        require(isinstance(review.get('submitted_at'), str), 'Missing review timestamp')
        timestamp = dt.datetime.fromisoformat(review['submitted_at'].replace('Z', '+00:00'))
        require(timestamp.tzinfo is not None, 'Review timestamp lacks timezone')
        sha(review['commit_id'])
        rank = (timestamp, review['id'])
        old = latest.get(reviewer['id'])
        if old is None or rank > old[0]:
            latest[reviewer['id']] = (rank, review)
    gate(not any(r['state'] == 'CHANGES_REQUESTED' for _, r in latest.values()), 'Outstanding changes requested')
    approval = latest.get(OWNER['id'])
    gate(approval is not None and user(approval[1]['user'], OWNER) and approval[1]['state'] == 'APPROVED' and approval[1]['commit_id'] == head, 'Missing current-head owner approval')


def checks(api, head):
    combined = api.get(f'/commits/{head}/status?per_page=100&page=1')
    require(combined.get('sha') == head and type(combined.get('total_count')) is int, 'Invalid combined status identity')
    statuses = api.pages(f'/commits/{head}/status', 10, 'statuses')
    require(len(statuses) == combined['total_count'], 'Status count race')
    unique(statuses, 'context')
    require(all(isinstance(s['context'], str) and s['context'] and type(s['id']) is int and s['id'] > 0 for s in statuses), 'Invalid status identity')
    gate(combined['state'] == ('success' if statuses else 'pending'), 'Statuses not successful')
    gate(all(s['state'] == 'success' for s in statuses), 'Failing or pending status')
    runs = api.pages(f'/commits/{head}/check-runs?filter=latest', 10, 'check_runs')
    unique(runs, 'id')
    keys = []
    for run in runs:
        require(type(run['id']) is int and run['id'] > 0 and type(run['app']['id']) is int and run['app']['id'] > 0 and isinstance(run['name'], str) and run['name'], 'Invalid check identity')
        require(run['head_sha'] == head, 'Check has wrong commit identity')
        gate(run['status'] == 'completed' and run['conclusion'] == 'success', 'Check not successful on exact commit')
        keys.append((run['app']['id'], run['name']))
    require(len(keys) == len(set(keys)), 'Ambiguous latest check runs')
    return {'statuses': statuses, 'runs': runs}


def validate(api, snapshot, number):
    pr = snapshot['prs'][str(number)]
    require(user(pr['user'], AUTHOR), 'Other author')
    gate(pr['state'] == 'open' and pr['draft'] is False and pr['merged'] is False, 'Draft or closed PR')
    gate(pr['base']['ref'] == 'main' and pr['base']['repo']['full_name'] == REPO, 'Wrong target repository/branch')
    head, base = sha(pr['head']['sha']), sha(pr['base']['sha'])
    repo = api.get('')
    require(repo['full_name'] == REPO and user(repo['owner'], OWNER) and repo['archived'] is False and repo['disabled'] is False and repo['allow_merge_commit'] is True, 'Repository policy unavailable')
    permission = api.get('/collaborators/revmnds/permission')
    gate(user(permission['user'], AUTHOR) and permission['permission'] in {'write', 'admin'} and permission['user']['permissions']['push'] is True, 'Author lacks current write permission')
    branch = api.get('/branches/main')
    require(branch['name'] == 'main' and sha(branch['commit']['sha']) == base, 'Base branch moved')
    # Do not rely on an owner's permission to bypass branch/ruleset requirements.
    # Supporting rule-managed branches requires a separately reviewed policy adapter.
    gate(branch['protected'] is False, 'Protected branch requires separate policy support')
    rules = api.pages('/rules/branches/main', 5)
    require(isinstance(rules, list), 'Missing active branch rules')
    gate(not rules, 'Active branch rules require separate policy support')
    gate(pr['mergeable'] is True and pr['mergeable_state'] == 'clean', 'Mergeability or policy not clean')
    reviews = api.pages(f'/pulls/{number}/reviews', 10)
    reviews_allow(reviews, head)
    head_checks = checks(api, head)
    gate(head_checks['statuses'] or head_checks['runs'], 'No passing head checks')
    merge_head = sha(pr['merge_commit_sha'])
    merge_checks = checks(api, merge_head) if merge_head != head else head_checks
    return {'pr': pr_identity(pr), 'mergeable': pr['mergeable'], 'mergeable_state': pr['mergeable_state'],
            'merge_head': merge_head, 'permission': permission, 'repo': {'full_name': repo['full_name'], 'owner': repo['owner'], 'allow_merge_commit': repo['allow_merge_commit']},
            'base': branch['commit']['sha'], 'protected': branch['protected'], 'rules': rules,
            'reviews': reviews, 'checks': {'head': head_checks, 'merge': merge_checks}}


def evaluate(api, apply=False, intent=None):
    require(not apply or api.apply, 'Apply mode not enabled in transport')
    first = world(api)
    skipped = []
    for number in sorted(first['prs'], key=int):
        pr = first['prs'][number]
        if not user(pr.get('user'), AUTHOR) or pr.get('draft') is not False:
            skipped.append({'pr': int(number), 'reason': 'Other author or draft'})
            continue
        try:
            attestation = validate(api, first, int(number))
        except NotReady as exc:
            skipped.append({'pr': int(number), 'reason': str(exc)})
            continue
        second = world(api)
        require(fingerprint(first) == fingerprint(second), 'Scope/head/base snapshot changed before merge')
        current = validate(api, second, int(number))
        require(fingerprint(attestation) == fingerprint(current), 'Permission/review/check identity changed before merge')
        final = api.get(f'/pulls/{number}')
        require(pr_identity(final) == current['pr'] and final['mergeable'] is True and final['mergeable_state'] == 'clean' and final['merge_commit_sha'] == current['merge_head'], 'Final PR identity changed')
        result = {'action': 'eligible-dry-run', 'pr': int(number), 'head': pr['head']['sha'], 'base': pr['base']['sha'], 'gate_sha256': fingerprint(current), 'skipped': skipped}
        if apply:
            require(intent is not None, 'Durable merge intent required')
            intent(result)
            response = api.merge(int(number), result['head'])
            require(response.get('merged') is True and isinstance(response.get('sha'), str) and SHA.fullmatch(response['sha']), 'Merge outcome uncertain')
            result.update(action='merged', merge_sha=response['sha'])
        return result
    return {'action': 'no-candidate', 'skipped': skipped}


def backoff(failures, retry=0):
    return max(30 if not failures else min(900, 30 * 2 ** min(failures - 1, 5)) + random.uniform(0, 5), retry)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--apply', action='store_true', help='Enable merges after independent reviews and root activation')
    parser.add_argument('--runtime', type=Path, required=True, help='Dedicated local state directory; do not use watchdog state')
    args = parser.parse_args()
    require(hashlib.sha256(Path(__file__).with_name('claims.py').read_bytes()).hexdigest() == CLAIMS_SHA, 'Pinned claims checker changed')
    runtime = args.runtime.resolve()
    runtime.mkdir(parents=True, exist_ok=True)
    with (runtime / 'lock').open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error('Acceptance worker runtime already locked')
        path = runtime / 'state.json'
        state = json.loads(path.read_text()) if path.exists() else {'version': 1, 'repo': REPO, 'failure_count': 0}
        require(isinstance(state, dict) and state.get('version') == 1 and state.get('repo') == REPO, 'Incompatible state; preserve runtime')
        require(type(state.get('failure_count')) is int and state['failure_count'] >= 0, 'Invalid persisted retry count')
        stopped = False
        def stop(signum, frame):
            nonlocal stopped
            stopped = True
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        source_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        attempts = 0
        if not args.once:
            while not stopped and time.time() < state.get('next_attempt_epoch', 0):
                time.sleep(min(1, max(0, state['next_attempt_epoch'] - time.time())))
        while not stopped:
            attempts += 1
            api = GitHub(args.apply)
            error, retry = None, 0
            result = None
            try:
                if state.get('merge_intent'):
                    pending = state['merge_intent']
                    pr = api.get(f"/pulls/{pending['pr']}")
                    require(pr['head']['sha'] == pending['head'] and pr['state'] == 'closed' and pr['merged'] is True, 'Uncertain merge intent requires operator reconciliation')
                    result = {'action': 'reconciled-merge', 'pr': pending['pr'], 'head': pending['head'], 'merge_sha': sha(pr['merge_commit_sha'])}
                else:
                    def intent(decision):
                        state['merge_intent'] = decision
                        atomic(path, state)
                    result = evaluate(api, args.apply, intent)
                with (runtime / 'events.jsonl').open('a') as events:
                    events.write(json.dumps({'utc': utc(), 'result': result}) + '\n')
                    events.flush()
                    os.fsync(events.fileno())
                state.pop('merge_intent', None)
                state['failure_count'] = 0
                state['last_success_utc'] = utc()
            except (Unavailable, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
                state['failure_count'] = state.get('failure_count', 0) + 1
                error = str(exc) if isinstance(exc, Unavailable) else type(exc).__name__
                retry = exc.retry_after if isinstance(exc, Unavailable) else 0
                if isinstance(exc, Unavailable) and exc.mutation and exc.http_status in {403, 404, 405, 409, 422}:
                    state.pop('merge_intent', None)
            wait = backoff(state['failure_count'], retry)
            state['next_attempt_epoch'] = time.time() + wait
            atomic(path, state)
            heartbeat = {'utc': utc(), 'pid': os.getpid(), 'process_start': Path('/proc/self/stat').read_text().rsplit(')', 1)[1].split()[19],
                         'mode': 'once' if args.once else 'continuous', 'apply': args.apply, 'code_sha256': source_hash,
                         'attempts': attempts, 'error': error, 'failure_count': state['failure_count'],
                         'last_success_utc': state.get('last_success_utc'), 'next_attempt_seconds': wait,
                         'merge_intent': state.get('merge_intent'), 'result': result, 'api_calls': api.calls, 'api_records': api.records}
            atomic(runtime / 'heartbeat.json', heartbeat)
            print(json.dumps(heartbeat, sort_keys=True), flush=True)
            if args.once:
                return 2 if error else 0
            while not stopped and time.time() < state['next_attempt_epoch']:
                time.sleep(min(1, max(0, state['next_attempt_epoch'] - time.time())))
        atomic(runtime / 'stopped.json', {'utc': utc(), 'pid': os.getpid()})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
