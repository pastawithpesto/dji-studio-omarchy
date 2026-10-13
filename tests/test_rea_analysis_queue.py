"""Research queue controls. These tests do not execute a vendor binary."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import threading
import unittest

SPEC = importlib.util.spec_from_file_location("rea_analysis_queue", Path(__file__).parents[1] /
                                           "tools/rea_analysis_queue.py")
queue = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(queue)


class QueueTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.binary = self.root / "original.dll"
        self.binary.write_bytes(b"\x90\xc3")
        self.provider = {"id": "ghidra", "name": "Ghidra", "version": "12.1.4"}
        self.producer = {"rea_commit": None, "rea_version": "6.4.0",
                         "mcp_server_version": "6.4.0", "provider": self.provider,
                         "analysis_profile_digest": "a" * 64}
        self.evidence = {
            "evidence_id": "ev_" + "b" * 64,
            "subject": {"digest": {"sha256": queue.sha_file(self.binary)}},
            "provider": self.provider,
            "analysis_profile": {"provider": self.provider, "digest": "a" * 64},
            "operation": "analyze_function", "parameters": {"procedure": "0x1000"},
            "normalized_result": {"procedure": {"address": "0x1000", "body": {
                "available": True, "contains_entry": True, "total_bytes": 2,
                "ranges": [{"start": "0x1000", "end": "0x1001"}]}},
                "pseudocode": "void function(void) { return; }",
                "assembly": ["0x1000: NOP", "0x1001: RET"],
                "limitations": ["Types are uncertain."]},
            "limitations": ["Saved evidence; no live image."]}
        self.saved = self.root / "saved.json"
        self.saved.write_text(json.dumps({"content": [{"type": "text", "text":
                                              json.dumps(self.evidence)}]}))
        self.job = {"id": "one", "binary": {"path": str(self.binary),
                    "sha256": queue.sha_file(self.binary), "build": "test-build"},
                    "address": "0x1000", "producer": self.producer,
                    "saved_evidence": [{"path": str(self.saved), "sha256": queue.sha_file(self.saved)}],
                    "byte_witnesses": [{"address": "0x1000", "file_offset": 0,
                       "hex": "90c3", "provenance": "Original file offset; test fixture"}]}
        self.manifest = {"schema_version": 1, "queue_id": "test", "jobs": [self.job]}
        self.manifest_path = self.root / "manifest.json"
        self.output = self.root / "queue"

    def tearDown(self):
        self.temp.cleanup()

    def run_queue(self, manifest=None):
        self.manifest_path.write_text(json.dumps(manifest or self.manifest))
        return queue.run_queue(self.manifest_path, self.output)

    def test_saved_reuse_resumes_without_new_attempt(self):
        first = self.run_queue()
        second = self.run_queue()
        self.assertEqual(first["counts"]["evidence_ready"], 1)
        self.assertTrue(second["results"][0]["resumed"])
        self.assertEqual(len(list((self.output / "jobs/one").iterdir())), 1)
        self.assertEqual(len(list((self.output / "reports").iterdir())), 2)
        self.assertEqual(first["results"][0]["producer"]["rea_commit"], None)
        self.assertEqual(first["results"][0]["coverage"]["mapping_status"], "supplied_provenance")
        self.assertIn("Types are uncertain.", first["results"][0]["limitations"])

    def test_source_change_invalidates_resume_and_records_failure(self):
        self.run_queue()
        self.binary.write_bytes(b"different")
        result = self.run_queue()["results"][0]
        self.assertEqual(result["status"], "failed")
        self.assertIn("Binary SHA-256", result["error"])
        self.assertEqual(len(list((self.output / "jobs/one").iterdir())), 2)

    def test_raw_saved_change_is_not_trusted(self):
        self.run_queue()
        self.saved.write_text("{}")
        result = self.run_queue()["results"][0]
        self.assertEqual(result["status"], "failed")
        self.assertIn("Saved input SHA-256", result["error"])

    def test_cached_evidence_tamper_fails(self):
        first = self.run_queue()["results"][0]
        file = Path(first["attempt"]) / "evidence.json"
        file.chmod(0o644)
        file.write_text("{}")
        result = self.run_queue()["results"][0]
        self.assertEqual(result["status"], "failed")
        self.assertIn("artifact hash mismatch", result["error"])

    def test_manifest_change_requires_new_directory(self):
        self.run_queue()
        changed = copy.deepcopy(self.manifest)
        changed["jobs"][0]["producer"]["rea_version"] = "changed"
        with self.assertRaisesRegex(queue.QueueError, "manifest has changed"):
            self.run_queue(changed)

    def test_missing_pseudocode_is_partial(self):
        del self.evidence["normalized_result"]["pseudocode"]
        result = queue.check_evidence(self.evidence, self.job)
        self.assertEqual(result["status"], "partial")
        self.assertFalse(result["coverage"]["pseudocode"])

    def test_bad_data_is_partial(self):
        self.evidence["normalized_result"]["pseudocode"] = "halt_baddata();"
        self.assertEqual(queue.check_evidence(self.evidence, self.job)["status"], "partial")

    def test_no_witness_does_not_claim_whole_body(self):
        self.job["byte_witnesses"] = []
        result = queue.check_evidence(self.evidence, self.job)
        self.assertEqual(result["status"], "partial")
        self.assertFalse(result["coverage"]["whole_body_witness"])

    def test_all_output_identities_fail_closed(self):
        for field, change in (
            ("subject", {"digest": {"sha256": "c" * 64}}),
            ("provider", {**self.provider, "version": "other"}),
            ("operation", "procedure_pseudo_code"),
            ("parameters", {"procedure": "0x1001"}),
            ("analysis_profile", {"provider": self.provider, "digest": "c" * 64}),
        ):
            evidence = {**self.evidence, field: change}
            with self.subTest(field=field), self.assertRaises(queue.QueueError):
                queue.check_evidence(evidence, self.job)
        self.evidence["normalized_result"]["procedure"]["address"] = "0x1001"
        with self.assertRaisesRegex(queue.QueueError, "entry does not match"):
            queue.check_evidence(self.evidence, self.job)

    def test_snapshot_and_full_envelope_select_exact_record(self):
        value = {"ok": True, "data": {"evidence_bundle": {"records": [self.evidence]}}}
        self.assertEqual(queue.select_evidence(value, self.job), self.evidence)
        value["data"]["evidence_bundle"]["records"].append(self.evidence)
        with self.assertRaisesRegex(queue.QueueError, "exactly one"):
            queue.select_evidence(value, self.job)

    def test_failure_retry_is_additive(self):
        self.job["saved_evidence"] = []
        first = self.run_queue()["results"][0]
        second = self.run_queue()["results"][0]
        self.assertEqual(first["status"], "failed")
        self.assertFalse(second["resumed"])
        self.assertNotEqual(first["attempt"], second["attempt"])
        self.assertTrue((Path(first["attempt"]) / "record.json").is_file())

    def test_exclusive_queue_lock(self):
        with queue.queue_lock(self.output):
            with self.assertRaisesRegex(queue.QueueError, "already locked"):
                self.run_queue()

    def test_duplicate_targets_and_path_traversal_are_rejected(self):
        self.manifest["jobs"].append({**self.job, "id": "two"})
        with self.assertRaisesRegex(queue.QueueError, "Duplicate binary/function"):
            queue.validate_manifest(self.manifest)
        self.manifest["jobs"] = [{**self.job, "id": "../escape"}]
        with self.assertRaisesRegex(queue.QueueError, "Invalid job ID"):
            queue.validate_manifest(self.manifest)

    def test_witness_source_mismatch_is_rejected(self):
        self.job["byte_witnesses"][0]["hex"] = "90cc"
        self.assertIn("witness", self.run_queue()["results"][0]["error"])

    def test_bounded_input(self):
        self.manifest["max_input_bytes"] = 8
        self.assertIn("exceeds byte limit", self.run_queue()["results"][0]["error"])

    def test_json_duplicates_and_nan_are_rejected(self):
        for raw in ('{"a":1,"a":2}', '{"a":NaN}'):
            with self.subTest(raw=raw), self.assertRaises(queue.QueueError):
                queue.load_json(raw)

    def test_grant_is_explicit_and_job_scoped(self):
        grant = {"allow_fresh_import": True, "authorization": "test only", "job_ids": ["one"],
                 "timeout_seconds": 1, "max_output_bytes": 100,
                 "address_space_mb": 512, "cpu_seconds": 2}
        queue.check_grant(grant, self.job)
        for changed in ({**grant, "allow_fresh_import": False},
                        {**grant, "job_ids": ["other"]}, {**grant, "timeout_seconds": float("nan")}):
            with self.assertRaises(queue.QueueError):
                queue.check_grant(changed, self.job)

    def process(self, source, timeout=1, cap=1024):
        directory = self.root / "process"
        directory.mkdir()
        return queue.run_process([sys.executable, "-c", source], directory, os.environ.copy(),
                                 {"timeout_seconds": timeout, "max_output_bytes": cap,
                                  "address_space_mb": 512, "cpu_seconds": 5}), directory

    def test_process_exit_and_stderr_preserved(self):
        result, directory = self.process("import sys; print('raw'); print('warning',file=sys.stderr); sys.exit(7)")
        self.assertEqual(result["returncode"], 7)
        self.assertEqual(result["process_status"], "exited")
        self.assertEqual((directory / "stdout.raw").read_bytes(), b"raw\n")
        self.assertEqual((directory / "stderr.raw").read_bytes(), b"warning\n")

    def test_process_output_is_bounded(self):
        result, directory = self.process("import sys; sys.stdout.write('x'*1000000)", cap=137)
        self.assertEqual(result["process_status"], "output_limit")
        self.assertEqual(sum((directory / name).stat().st_size for name in
                             ("stdout.raw", "stderr.raw")), 137)

    def test_timeout_kills_owned_descendant_group(self):
        child = self.root / "child.pid"
        script = ("import subprocess,time; p=subprocess.Popen(['" + sys.executable +
                  "','-c','import time; time.sleep(30)']); " +
                  f"open({str(child)!r},'w').write(str(p.pid)); time.sleep(30)")
        result, _ = self.process(script, timeout=0.2)
        self.assertEqual(result["process_status"], "timeout")
        pid = int(child.read_text())
        for _ in range(50):
            stat = Path(f"/proc/{pid}/stat")
            if not stat.exists() or stat.read_text().split()[2] == "Z":
                break
            time.sleep(0.02)
        else:
            os.kill(pid, signal.SIGKILL)
            self.fail("Owned child remained alive after timeout")

    def test_detached_child_timeout_is_reaped(self):
        child = self.root / "detached.pid"
        script = ("import subprocess,time; p=subprocess.Popen([" + repr(sys.executable) +
                  ",' -c'.strip(),'import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)']," +
                  "start_new_session=True); " +
                  f"open({str(child)!r},'w').write(str(p.pid)); time.sleep(30)")
        result, directory = self.process(script, timeout=0.2)
        self.assertEqual(result["process_status"], "timeout")
        pid = int(child.read_text())
        self.assertFalse(Path(f"/proc/{pid}").exists())
        self.assertEqual(result["cleanup"]["surviving_processes"], [])
        self.assertTrue((directory / "process-cleanup.json").is_file())

    def test_signal_interruption_cleans_detached_child(self):
        child = self.root / "interrupted.pid"
        script = ("import subprocess,time; p=subprocess.Popen([" + repr(sys.executable) +
                  ",' -c'.strip(),'import time; time.sleep(30)'],start_new_session=True); " +
                  f"open({str(child)!r},'w').write(str(p.pid)); time.sleep(30)")
        timer = threading.Timer(0.2, lambda: os.kill(os.getpid(), signal.SIGTERM))
        timer.start()
        try:
            with self.assertRaises(KeyboardInterrupt):
                self.process(script, timeout=5)
        finally:
            timer.cancel()
            timer.join()
        pid = int(child.read_text())
        self.assertFalse(Path(f"/proc/{pid}").exists())
        cleanup = json.loads((self.root / "process/process-cleanup.json").read_text())
        self.assertEqual(cleanup["surviving_processes"], [])

    def test_recomputed_local_seals_cannot_replace_saved_output(self):
        first = self.run_queue()["results"][0]
        directory = Path(first["attempt"])
        evidence = json.loads((directory / "evidence.json").read_text())
        evidence["normalized_result"]["pseudocode"] = "fabricated code"
        record = json.loads((directory / "record.json").read_text())
        for name in ("evidence.json", "record.json", "record.sha256"):
            (directory / name).chmod(0o644)
        (directory / "evidence.json").write_bytes(queue.canonical(evidence) + b"\n")
        record["artifacts"]["evidence.json"] = queue.sha_file(directory / "evidence.json")
        (directory / "record.json").write_bytes(queue.canonical(record) + b"\n")
        (directory / "record.sha256").write_text(queue.sha_file(directory / "record.json") + "\n")
        result = self.run_queue()["results"][0]
        self.assertEqual(result["status"], "failed")
        self.assertIn("pinned saved raw input", result["error"])

    def test_historical_report_without_source(self):
        self.run_queue()
        self.binary.unlink()
        self.saved.unlink()
        report = queue.historical_report(self.output)
        result = report["results"][0]
        self.assertEqual(result["current_input_verification"]["status"], "failed_or_unavailable")
        self.assertEqual(result["attempts"][0]["status"], "evidence_ready")
        self.assertEqual(report["mode"], "historical_report")

    def test_malformed_and_conflicting_wrappers_fail(self):
        for value in ({"content": ["invalid"]},
                      {"evidence_bundle": {"records": ["invalid"]}},
                      {"evidence_bundle": "invalid"},
                      {"content": [{"type": "text", "text": json.dumps(self.evidence)}],
                       "structuredContent": {**self.evidence, "operation": "other"}}):
            with self.subTest(value=value), self.assertRaises(queue.QueueError):
                queue.select_evidence(value, self.job)

    def test_output_budget_cleans_detached_child(self):
        child = self.root / "budget.pid"
        script = ("import subprocess,sys,time; p=subprocess.Popen([" + repr(sys.executable) +
                  ",' -c'.strip(),'import time; time.sleep(30)'],start_new_session=True); " +
                  f"open({str(child)!r},'w').write(str(p.pid)); sys.stdout.write('x'*1000000)")
        result, _ = self.process(script, timeout=5, cap=100)
        self.assertEqual(result["process_status"], "output_limit")
        self.assertFalse(Path(f"/proc/{int(child.read_text())}").exists())

    def test_cleanup_preserves_existing_peer_child(self):
        peer = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        try:
            result, _ = self.process("import time; time.sleep(30)", timeout=0.05)
            self.assertEqual(result["process_status"], "timeout")
            self.assertIsNone(peer.poll())
            self.assertNotIn(peer.pid, [item["pid"] for item in result["cleanup"]["owned_processes"]])
        finally:
            peer.kill()
            peer.wait(timeout=5)

    def test_malformed_saved_probe_has_a_sealed_failure(self):
        self.saved.write_text('{"content":["invalid"]}')
        self.job["saved_evidence"][0]["sha256"] = queue.sha_file(self.saved)
        result = self.run_queue()["results"][0]
        self.assertEqual(result["status"], "failed")
        self.assertTrue((Path(result["attempt"]) / "record.sha256").is_file())
        probes = json.loads((Path(result["attempt"]) / "saved-probes.json").read_text())
        self.assertIn("Invalid MCP content", probes[0]["error"])

    def test_runtime_tree_change_changes_identity(self):
        directory = self.root / "dist"
        directory.mkdir()
        file = directory / "cli.js"
        file.write_text("a")
        initial = queue.tree_digest(directory)
        file.write_text("b")
        self.assertNotEqual(queue.tree_digest(directory), initial)
        (directory / "link").symlink_to(file)
        with self.assertRaisesRegex(queue.QueueError, "symbolic link"):
            queue.tree_digest(directory)


if __name__ == "__main__":
    unittest.main()
