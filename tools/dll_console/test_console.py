"""Focused stdlib regression tests for the local DLL console's boundaries."""
import hashlib
import http.client
import json
import struct
import sqlite3
import sys
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import data
import jobs
import server
from pe import inspect_pe


def minimal_pe():
    """Build a small PE32+ image with one named forwarder and one ordinal export."""
    blob = bytearray(0x600)
    blob[:2] = b'MZ'
    struct.pack_into('<I', blob, 60, 0x80)
    blob[0x80:0x84] = b'PE\0\0'
    struct.pack_into('<HHIIIHH', blob, 0x84, 0x8664, 1, 0, 0, 0, 0xF0, 0x2022)
    opt = 0x98
    struct.pack_into('<H', blob, opt, 0x20B)
    struct.pack_into('<Q', blob, opt + 24, 0x180000000)
    struct.pack_into('<I', blob, opt + 60, 0x200)
    struct.pack_into('<I', blob, opt + 108, 16)
    struct.pack_into('<II', blob, opt + 112, 0x1000, 0x100)

    section = opt + 0xF0
    blob[section:section + 8] = b'.rdata\0\0'
    struct.pack_into('<IIII', blob, section + 8, 0x400, 0x1000, 0x400, 0x200)
    struct.pack_into('<I', blob, section + 36, 0x40000040)

    export = 0x200
    struct.pack_into('<IIIIII', blob, export + 16, 1, 2, 1, 0x1040, 0x1048, 0x1050)
    struct.pack_into('<II', blob, 0x240, 0x1090, 0x1100)
    struct.pack_into('<I', blob, 0x248, 0x1060)
    struct.pack_into('<H', blob, 0x250, 0)
    blob[0x260:0x268] = b'NamedFn\0'
    forwarder = b'KERNEL32.Sleep\0'
    blob[0x290:0x290 + len(forwarder)] = forwarder
    return bytes(blob)


class PeTests(unittest.TestCase):
    def inspect_bytes(self, payload):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = Path(temp.name) / 'fixture.dll'
        path.write_bytes(payload)
        return inspect_pe(path)

    def test_named_forwarder_ordinal_and_section_metadata(self):
        payload = minimal_pe()
        result = self.inspect_bytes(payload)
        self.assertEqual(result['machine'], 0x8664)
        self.assertEqual(result['image_base'], '0x180000000')
        self.assertEqual(result['sections'][0]['name'], '.rdata')
        self.assertEqual(result['sections'][0]['va'], '0x180001000')
        self.assertEqual(result['sha256'], hashlib.sha256(payload).hexdigest())
        self.assertEqual(result['exports'], [
            {'name': 'NamedFn', 'ordinal': 1, 'va': '0x180001090',
             'rva': 0x1090, 'forwarder': 'KERNEL32.Sleep'},
            {'name': 'ordinal 2', 'ordinal': 2, 'va': '0x180001100',
             'rva': 0x1100, 'forwarder': None},
        ])

    def test_rejects_truncated_header_and_section_outside_file(self):
        with self.assertRaisesRegex(ValueError, 'Truncated PE header'):
            self.inspect_bytes(b'MZ')
        payload = bytearray(minimal_pe())
        struct.pack_into('<I', payload, 0x188 + 16, 0x1000)
        with self.assertRaisesRegex(ValueError, 'Section bytes are outside'):
            self.inspect_bytes(payload)

    def test_rejects_export_rva_that_does_not_map_to_file_bytes(self):
        payload = bytearray(minimal_pe())
        struct.pack_into('<I', payload, 0x98 + 112, 0x9000)
        with self.assertRaisesRegex(ValueError, 'RVA has no complete'):
            self.inspect_bytes(payload)

    def test_rejects_export_name_ordinal_outside_function_table(self):
        payload = bytearray(minimal_pe())
        struct.pack_into('<H', payload, 0x250, 2)
        with self.assertRaisesRegex(ValueError, 'Export ordinal exceeds'):
            self.inspect_bytes(payload)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'project'
        self.source = Path(self.temp.name) / 'source'
        self.root.mkdir()
        self.source.mkdir()

    def write_seed(self, seed):
        (self.source / 'catalog.json').write_text(json.dumps(seed))

    def test_review_state_checks_pinned_candidate_and_downgrades_mismatch(self):
        contract = self.root / 'contracts' / 'CONTRACT.json'
        contract.parent.mkdir()
        contract.write_text('{"scope":"bounded"}\n')
        digest = hashlib.sha256(contract.read_bytes()).hexdigest()
        review = {
            'decision': 'approved_bounded_contract',
            'candidate': {'contract': 'contracts/CONTRACT.json', 'contract_sha256': digest},
        }
        (self.root / 'review.json').write_text(json.dumps(review))
        self.write_seed({})
        catalog = data.Catalog(self.root, self.source)
        part = {'research': 'unreviewed', 'review_json': 'review.json'}
        self.assertEqual(catalog.evidence_state(part)['research'], 'reviewed')

        contract.write_text('{"scope":"changed"}\n')
        part = {'research': 'unreviewed', 'review_json': 'review.json'}
        self.assertEqual(catalog.evidence_state(part)['research'], 'blocked')

    def test_changed_review_record_and_pinned_markdown_review_block_status(self):
        review = self.root / 'review.json'
        review.write_text(json.dumps({'decision': 'approved'}))
        original_review_hash = hashlib.sha256(review.read_bytes()).hexdigest()
        markdown = self.root / 'REVIEW.md'
        markdown.write_text('Disposition: approved for the bounded scalar Rust leaf.\n')
        original_markdown_hash = hashlib.sha256(markdown.read_bytes()).hexdigest()
        self.write_seed({})
        catalog = data.Catalog(self.root, self.source)

        pinned_json = {'research': 'unreviewed', 'review_json': 'review.json', 'review_sha256': original_review_hash}
        self.assertEqual(catalog.evidence_state(pinned_json)['research'], 'reviewed')
        review.write_text(json.dumps({'decision': 'changes_requested'}))
        changed_json = {'research': 'reviewed', 'review_json': 'review.json', 'review_sha256': original_review_hash}
        self.assertEqual(catalog.evidence_state(changed_json)['research'], 'blocked')

        pinned_markdown = {'research': 'unreviewed', 'review_markdown': 'REVIEW.md', 'review_sha256': original_markdown_hash}
        self.assertEqual(catalog.evidence_state(pinned_markdown)['research'], 'reviewed')
        markdown.write_text('Disposition: changes requested.\n')
        changed_markdown = {'research': 'reviewed', 'review_markdown': 'REVIEW.md', 'review_sha256': original_markdown_hash}
        self.assertEqual(catalog.evidence_state(changed_markdown)['research'], 'blocked')

    def test_missing_or_invalid_review_is_not_treated_as_approved(self):
        self.write_seed({})
        catalog = data.Catalog(self.root, self.source)
        missing = {'research': 'reviewed', 'review_json': 'absent.json'}
        self.assertEqual(catalog.evidence_state(missing)['research'], 'unreviewed')
        missing_decision = self.root / 'changes.json'
        missing_decision.write_text(json.dumps({'decision': 'changes_requested'}))
        blocked = {'research': 'reviewed', 'review_json': 'changes.json'}
        self.assertEqual(catalog.evidence_state(blocked)['research'], 'blocked')

    def test_artifacts_require_allowlist_and_stay_inside_project(self):
        evidence = self.root / 'evidence'
        evidence.mkdir()
        (evidence / 'review.md').write_text('bounded evidence')
        outside = Path(self.temp.name) / 'outside.md'
        outside.write_text('secret')
        (evidence / 'escape.md').symlink_to(outside)
        seed = {'Fixture.dll': {'parts': [{'evidence': [
            {'path': 'evidence/review.md'},
            {'path': 'evidence/escape.md'},
            {'path': '../outside.md'},
        ]}]}}
        self.write_seed(seed)
        catalog = data.Catalog(self.root, self.source)
        self.assertEqual(catalog.artifact('evidence/review.md'), b'bounded evidence')
        with self.assertRaisesRegex(ValueError, 'not a declared'):
            catalog.artifact('evidence/../outside.md')
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            catalog.artifact('evidence/escape.md')
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            catalog.artifact('../outside.md')


class FakeCatalog:
    def module(self, ident):
        if ident != 'Fixture.dll':
            raise ValueError('Unknown DLL')
        return {'id': ident, 'path': 'extracted/Fixture.dll', 'sha256': 'a' * 64,
                'parts': [
                    {'id': 'part-a', 'label': 'Part A', 'detail': 'First scope', 'addresses': [], 'missing': [], 'evidence': []},
                    {'id': 'part-b', 'label': 'Part B', 'detail': 'Second scope', 'addresses': [], 'missing': [], 'evidence': []},
                ], 'exports': []}

    def selections(self, module, ids):
        if not isinstance(ids, list) or not ids or len(set(ids)) != len(ids):
            raise ValueError('Unknown or duplicate selected part')
        available = {p['id']: p for p in module['parts']}
        if any(item not in available for item in ids):
            raise ValueError('Unknown or duplicate selected part')
        return [available[item] for item in ids]


def valid_request(parts=('part-a',), action='research', model='luna', notes=''):
    return {'dll': 'Fixture.dll', 'parts': list(parts), 'action': action, 'model': model, 'notes': notes}


class QueueTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / 'project'
        self.runtime = Path(self.temp.name) / 'runtime'
        self.project.mkdir()
        self.queue = jobs.Queue(self.project, self.runtime, FakeCatalog(), launch=False)

    def test_preview_validates_action_model_parts_and_notes(self):
        result, _, _ = self.queue.preview(valid_request())
        self.assertEqual(result['selection_summary'], 'Part A')
        for request in (
            valid_request(model='unknown'),
            valid_request(action='merge'),
            valid_request(parts=()),
            valid_request(parts=('part-a', 'part-a')),
            valid_request(notes='x' * 8001),
        ):
            with self.subTest(request=request):
                with self.assertRaises(ValueError):
                    self.queue.preview(request)

    def test_enqueue_rejects_overlapping_active_scope_but_accepts_disjoint(self):
        first = self.queue.enqueue(valid_request(('part-a',), action='research'))
        self.assertEqual(first['status'], 'queued')
        with self.assertRaisesRegex(ValueError, 'already owns this selection'):
            self.queue.enqueue(valid_request(('part-a',), action='research'))
        other = self.queue.enqueue(valid_request(('part-b',), action='research'))
        self.assertEqual(other['parts'], ['part-b'])
        different_action = self.queue.enqueue(valid_request(('part-a',), action='review'))
        self.assertEqual(different_action['action'], 'review')

    def test_pause_never_signals_when_owned_process_identity_fails(self):
        job = self.queue.enqueue(valid_request())
        stored = self.queue.jobs[job['id']]
        stored.update(status='running', pid=12345, start_ticks='999')
        job = stored
        self.queue.save(job)
        with patch('jobs.alive', return_value=False), patch('jobs.os.killpg') as killpg:
            with self.assertRaisesRegex(ValueError, 'no signal sent'):
                self.queue.pause(job['id'])
            killpg.assert_not_called()

    def test_pause_never_signals_when_process_cwd_is_not_job_output(self):
        job = self.queue.enqueue(valid_request())
        stored = self.queue.jobs[job['id']]
        stored.update(status='running', pid=12345, start_ticks='999')
        job = stored
        self.queue.save(job)
        with patch('jobs.alive', return_value=True), patch('jobs.os.getpgid', return_value=12345), patch('jobs.Path.resolve', return_value=Path('/tmp/unrelated')):
            with patch('jobs.os.killpg') as killpg:
                with self.assertRaisesRegex(ValueError, 'no signal sent'):
                    self.queue.pause(job['id'])
                killpg.assert_not_called()

    def test_pause_never_signals_when_pid_is_not_its_own_process_group(self):
        job = self.queue.enqueue(valid_request())
        stored = self.queue.jobs[job['id']]
        stored.update(status='running', pid=12345, start_ticks='999')
        job = stored
        self.queue.save(job)
        with patch('jobs.alive', return_value=True), patch('jobs.os.getpgid', return_value=12346), patch('jobs.os.killpg') as killpg:
            with self.assertRaisesRegex(ValueError, 'no signal sent'):
                self.queue.pause(job['id'])
            killpg.assert_not_called()

    def running_job_with_log(self, contents, model='kimi'):
        job = self.queue.enqueue(valid_request(model=model))
        job = self.queue.jobs[job['id']]
        log = self.runtime / 'logs' / (job['id'] + '.jsonl')
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_bytes(contents)
        job.update(status='running', model=model, log=str(log), pid=12345, start_ticks='999')
        self.queue.save(job)
        return job, log

    def test_opencode_step_finish_stop_completes_successful_turn(self):
        event = {'type': 'step_finish', 'sessionID': 'ses_abc123',
                 'part': {'reason': 'stop', 'tokens': {'input': 17, 'output': 4}}}
        job, _ = self.running_job_with_log((json.dumps(event) + '\n').encode())

        class FinishedProcess:
            def poll(self):
                return 0

        self.queue.processes[job['id']] = FinishedProcess()
        with patch.object(self.queue, 'owned_process', return_value=False):
            self.queue.tick()
        self.assertEqual(self.queue.jobs[job['id']]['status'], 'completed')
        self.assertEqual(self.queue.jobs[job['id']]['session'], 'ses_abc123')
        self.assertEqual(self.queue.jobs[job['id']]['usage'], {'input_tokens': 17, 'output_tokens': 4})

    def test_reasoning_and_tool_log_content_never_enters_public_state_or_artifacts(self):
        secrets_in_log = ('private_reasoning_marker_91d4', 'private_tool_result_marker_70ba')
        events = [
            {'type': 'response_item', 'payload': {'type': 'reasoning', 'text': secrets_in_log[0]}},
            {'type': 'tool_use', 'name': 'read_file', 'input': {'path': secrets_in_log[1]}},
        ]
        body = ''.join(json.dumps(event) + '\n' for event in events).encode()
        job, log = self.running_job_with_log(body)
        self.queue.read_events(job)

        app = object.__new__(server.App)
        app.csrf = 'fixture'
        app.catalog = SimpleNamespace(inventory=lambda: [])
        app.queue = self.queue
        app.usage = SimpleNamespace(snapshot=lambda: {'sessions': []})
        app.project = self.project
        with patch('server.workers', return_value=[]), patch('server.activity', return_value=[]):
            public = json.dumps(app.state())
        for secret in secrets_in_log:
            self.assertNotIn(secret, public)
        self.assertNotIn(body.decode(), public)
        self.assertEqual(log.read_bytes(), body)
        with self.assertRaisesRegex(ValueError, 'Unknown public job artifact'):
            app.job_artifact(job['id'], log.name)

    def test_oversized_event_line_is_skipped_and_following_completion_is_read(self):
        oversized = b'{"type":"private","padding":"' + b'x' * 1_000_100 + b'"}\n'
        completion = json.dumps({'type': 'turn.completed', 'usage': {
            'input_tokens': 20, 'output_tokens': 5, 'cached_input_tokens': 7,
        }}).encode() + b'\n'
        job, log = self.running_job_with_log(oversized + completion)
        self.queue.read_events(job)
        self.assertTrue(job['turn_completed'])
        self.assertEqual(job['usage'], {'input_tokens': 20, 'output_tokens': 5, 'cached_input_tokens': 7})
        self.assertEqual(self.queue.offsets[job['id']], log.stat().st_size)

    def test_stale_final_file_cannot_complete_without_verified_event(self):
        job, _ = self.running_job_with_log(b'{"type":"assistant_delta","text":"old"}\n')
        (self.queue.output / job['id'] / 'FINAL.txt').write_text('stale result')

        class FinishedProcess:
            def poll(self):
                return 0

        self.queue.processes[job['id']] = FinishedProcess()
        with patch.object(self.queue, 'owned_process', return_value=False):
            self.queue.tick()
        self.assertNotEqual(self.queue.jobs[job['id']]['status'], 'completed')
        self.assertNotIn('turn_completed', self.queue.jobs[job['id']])

    def test_queued_pause_resume_and_job_state_survive_restarts(self):
        job = self.queue.enqueue(valid_request(('part-b',), action='review', model='astra', notes='resume fixture'))
        paused = self.queue.pause(job['id'])
        self.assertEqual(paused['status'], 'paused')

        restarted = jobs.Queue(self.project, self.runtime, FakeCatalog(), launch=False)
        self.assertEqual(restarted.jobs[job['id']]['status'], 'paused')
        resumed = restarted.resume(job['id'])
        self.assertEqual(resumed['status'], 'queued')
        self.assertEqual(resumed['model'], 'astra')
        self.assertEqual(resumed['parts'], ['part-b'])
        self.assertEqual(resumed['notes'], 'resume fixture')

        after_resume_restart = jobs.Queue(self.project, self.runtime, FakeCatalog(), launch=False)
        self.assertEqual(after_resume_restart.jobs[job['id']]['status'], 'queued')
        self.assertEqual(after_resume_restart.jobs[job['id']]['model'], 'astra')


class UsageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'home'
        self.project = Path(self.temp.name) / 'project'
        (self.home / '.codex').mkdir(parents=True)
        self.project.mkdir()

    def add_codex_db(self, name, rows):
        path = self.home / '.codex' / name
        db = sqlite3.connect(path)
        try:
            db.execute('CREATE TABLE threads (id TEXT, model TEXT, tokens_used INTEGER, updated_at REAL, rollout_path TEXT, cwd TEXT)')
            db.executemany('INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?)', rows)
            db.commit()
        finally:
            db.close()

    def test_usage_deduplicates_codex_thread_ids_and_cache_is_a_subset_of_total(self):
        rollout = self.home / 'rollout.jsonl'
        event = {'type': 'event_msg', 'payload': {'type': 'token_count', 'info': {
            'total_token_usage': {'total_tokens': 100, 'input_tokens': 70, 'output_tokens': 30, 'cached_input_tokens': 20},
        }}}
        rollout.write_text(json.dumps(event) + '\n')
        self.add_codex_db('state-z.sqlite', [
            ('same-thread', 'gpt-6-luna', 999, 20.0, str(rollout), str(self.project)),
        ])
        self.add_codex_db('state-a.sqlite', [
            ('same-thread', 'gpt-6-luna-old', 50, 10.0, '', str(self.project)),
            ('second-thread', 'gpt-6-sol', 5, 9.0, '', str(self.project)),
        ])

        opencode_dir = self.home / '.local/share/opencode'
        opencode_dir.mkdir(parents=True)
        db = sqlite3.connect(opencode_dir / 'opencode.db')
        try:
            db.execute('CREATE TABLE session_v2 (id TEXT, model TEXT, tokens_input INTEGER, tokens_output INTEGER, tokens_cache_read INTEGER, time_updated INTEGER, directory TEXT)')
            db.execute('INSERT INTO session_v2 VALUES (?, ?, ?, ?, ?, ?, ?)',
                       ('open-session', '{"id":"kimi-k3"}', 12, 3, 8, 100000, str(self.project)))
            db.commit()
        finally:
            db.close()

        result = data.observed_usage(self.project, self.home)
        ids = [entry['id'] for entry in result['sessions']]
        self.assertEqual(ids.count('same-thread'), 1)
        self.assertEqual(len(ids), 3)
        self.assertEqual(result['total_tokens'], 120)
        self.assertEqual(result['input_tokens'], 82)
        self.assertEqual(result['output_tokens'], 33)
        self.assertEqual(result['cached_tokens'], 28)


class HttpGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        cls.server.daemon_threads = True
        cls.server.app = SimpleNamespace(
            csrf='fixture-session-token',
            queue=SimpleNamespace(preview=lambda request: ({'selection_summary': 'Part A', 'scope_blocker': None}, None, [])),
        )
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.port = cls.server.server_port

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def post(self, host=None, origin=None, token=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=3)
        headers = {'Content-Type': 'application/json'}
        headers['Connection'] = 'close'
        if host is not None:
            headers['Host'] = host
        if origin is not None:
            headers['Origin'] = origin
        if token is not None:
            headers['X-Console-Token'] = token
        body = json.dumps({'fixture': True})
        conn.request('POST', '/api/preview', body=body, headers=headers)
        response = conn.getresponse()
        status = response.status
        payload = response.read()
        conn.close()
        return status, payload

    def test_mutation_accepts_exact_local_host_origin_and_session_token(self):
        status, payload = self.post(
            host=f'127.0.0.1:{self.port}',
            origin=f'http://127.0.0.1:{self.port}',
            token='fixture-session-token',
        )
        self.assertEqual(status, 200)
        self.assertIn(b'Part A', payload)

    def test_mutation_rejects_missing_token_bad_origin_and_untrusted_host(self):
        valid = dict(host=f'localhost:{self.port}', origin=f'http://localhost:{self.port}')
        cases = [
            dict(valid, token=None),
            dict(host=valid['host'], origin='https://localhost', token='fixture-session-token'),
            dict(host=f'evil.example:{self.port}', origin=valid['origin'], token='fixture-session-token'),
        ]
        for headers in cases:
            with self.subTest(headers=headers):
                status, _ = self.post(**headers)
                self.assertEqual(status, 403)


if __name__ == '__main__':
    unittest.main()
