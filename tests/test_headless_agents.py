"""Synthetic record checks. These tests do not start native model sessions."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


HELPER = Path(__file__).resolve().parents[1] / "tools" / "headless_agents.py"
spec = importlib.util.spec_from_file_location("headless_agents", HELPER)
agents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agents)
# Synthetic IDs are test data. They do not identify verified native sessions.
ZCODE_ID = "sess_00000000-0000-4000-8000-000000000001"
DSH_ID = "session-00000000-0000-4000-8000-000000000002"


class HeadlessAgentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.store = self.base / "records"
        self.cwd = self.base / "source worktree"
        self.cwd.mkdir()
        self.overlay = self.base / "overlay.yml"
        self.overlay.write_text("# Synthetic overlay fixture\n")

    def command(self, *args, store=None):
        return [sys.executable, str(HELPER), "--store", str(store or self.store), *args]

    def run_helper(self, *args, success=True, store=None):
        result = subprocess.run(self.command(*args, store=store), text=True,
                                capture_output=True, check=False)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        if success:
            self.assertEqual(result.stderr, "")
            return json.loads(result.stdout)
        self.assertEqual(result.stdout, "")
        return result

    def register(self, name="research", tool="zcode", **options):
        args = ["register", name, "--tool", tool, "--session-id",
                ZCODE_ID if tool == "zcode" else DSH_ID, "--cwd", str(self.cwd)]
        for key, value in options.items():
            args.extend(["--" + key.replace("_", "-"), value])
        return self.run_helper(*args)

    def record_path(self, name="research"):
        return self.store / (name + ".json")

    def test_register_status_and_private_permissions(self):
        registered = self.register()
        self.assertEqual(registered, self.run_helper("status", "research"))
        self.assertEqual(registered["session_id"], ZCODE_ID)
        self.assertEqual(registered["cwd"], str(self.cwd))
        self.assertEqual(registered["mode"], "plan")
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.record_path().stat().st_mode & 0o777, 0o600)
        self.assertEqual(len(list(self.store.iterdir())), 1)

    def test_zcode_resume_passes_literal_arguments_without_persisting_task(self):
        self.register(mode="build")
        before = self.record_path().read_bytes()
        task = "Inspect $(touch should-not-exist); `echo example`\nNext task"
        result = self.run_helper("resume-argv", "research", "--task", task, "--json-output")
        self.assertEqual(result, {"cwd": str(self.cwd), "argv": [
            "zcode", "--cwd", str(self.cwd), "--mode", "build", "--resume",
            ZCODE_ID, "--prompt", task, "--json"]})
        self.assertEqual(self.record_path().read_bytes(), before)
        self.assertNotIn(task, before.decode())
        self.assertFalse((self.cwd / "should-not-exist").exists())

    def test_dsh_resume_sets_process_directory_and_orders_launcher_flags(self):
        self.register(tool="dsh", patch=str(self.overlay))
        result = self.run_helper("resume-argv", "research", "--task=-", "--json-output")
        self.assertEqual(result, {"cwd": str(self.cwd), "argv": [
            "dsh", "--profile", "headless", "--patch", str(self.overlay),
            "--session-id", DSH_ID, "--json", "--", "-"]})

    def test_dsh_without_overlay_and_option_like_task(self):
        self.register(tool="dsh")
        result = self.run_helper("resume-argv", "research", "--task=--help")
        self.assertEqual(result["argv"], ["dsh", "--profile", "headless",
                                         "--session-id", DSH_ID, "--", "--help"])

    def test_checkpoint_preserves_session_identity_and_options(self):
        original = self.register(resume_evidence="public-record-1")
        updated = self.run_helper("checkpoint", "research", "--text", "Review remains open.",
                                  "--resume-evidence", "public-record-2")
        for field in agents.FIELDS - {"checkpoint", "resume_evidence", "updated_utc"}:
            self.assertEqual(original[field], updated[field])
        self.assertEqual(updated["checkpoint"], "Review remains open.")
        self.assertEqual(updated["resume_evidence"], "public-record-2")
        self.assertEqual(updated, self.run_helper("status", "research"))

    def test_duplicate_registration_preserves_original(self):
        self.register()
        before = self.record_path().read_bytes()
        self.run_helper("register", "research", "--tool", "dsh", "--session-id", DSH_ID,
                        "--cwd", str(self.cwd), success=False)
        self.assertEqual(self.record_path().read_bytes(), before)

    def test_invalid_ids_and_names_do_not_create_records(self):
        for native_id in ("sess_", DSH_ID, ZCODE_ID + "/../x", "sess_not-native-uuid"):
            with self.subTest(native_id=native_id):
                self.run_helper("register", "research", "--tool", "zcode", "--session-id",
                                native_id, "--cwd", str(self.cwd), success=False)
        self.run_helper("register", "../escaped", "--tool", "zcode", "--session-id",
                        ZCODE_ID, "--cwd", str(self.cwd), success=False)
        self.assertEqual(list(self.store.iterdir()), [])

    def test_tool_options_reject_cross_tool_flags(self):
        self.run_helper("register", "research", "--tool", "dsh", "--session-id", DSH_ID,
                        "--cwd", str(self.cwd), "--mode", "plan", success=False)
        self.run_helper("register", "research", "--tool", "zcode", "--session-id", ZCODE_ID,
                        "--cwd", str(self.cwd), "--patch", str(self.overlay), success=False)
        self.assertFalse(self.record_path().exists())

    def test_invalid_checkpoint_does_not_replace_record_or_echo_content(self):
        self.register()
        before = self.record_path().read_bytes()
        for text in ("PRIVATE_SENTINEL\nraw event", "x" * 501):
            result = self.run_helper("checkpoint", "research", "--text", text, success=False)
            self.assertNotIn("PRIVATE_SENTINEL", result.stderr)
            self.assertEqual(self.record_path().read_bytes(), before)

    def test_corrupt_unknown_and_large_records_are_not_printed(self):
        record = self.register()
        for value in ("PRIVATE_SENTINEL invalid JSON", json.dumps({**record, "secret": "PRIVATE_SENTINEL"}),
                      json.dumps({**record, "schema": True}), "x" * (agents.MAX_RECORD + 1)):
            self.record_path().write_text(value)
            result = self.run_helper("status", "research", success=False)
            self.assertNotIn("PRIVATE_SENTINEL", result.stderr)

    def test_store_and_ancestor_symlinks_are_rejected(self):
        self.register()
        link = self.base / "linked-store"
        link.symlink_to(self.store, target_is_directory=True)
        self.run_helper("status", "research", store=link, success=False)
        ancestor = self.base / "linked-parent"
        ancestor.symlink_to(self.base, target_is_directory=True)
        self.run_helper("status", "research", store=ancestor / "records", success=False)

    def test_record_symlink_and_hard_link_are_rejected(self):
        self.register()
        target = self.base / "target.json"
        self.record_path().rename(target)
        before = target.read_bytes()
        self.record_path().symlink_to(target)
        self.run_helper("checkpoint", "research", "--text", "Updated", success=False)
        self.assertEqual(target.read_bytes(), before)
        self.record_path().unlink()
        os.link(target, self.record_path())
        self.run_helper("status", "research", success=False)
        self.assertEqual(target.read_bytes(), before)

    def test_public_store_and_record_are_rejected(self):
        self.register()
        self.record_path().chmod(0o644)
        self.run_helper("status", "research", success=False)
        self.record_path().chmod(0o600)
        self.store.chmod(0o755)
        self.run_helper("checkpoint", "research", "--text", "Updated", success=False)

    def test_fifo_record_does_not_block(self):
        self.register()
        self.record_path().unlink()
        os.mkfifo(self.record_path(), 0o600)
        result = subprocess.run(self.command("status", "research"), text=True,
                                capture_output=True, timeout=5, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")

    def test_missing_or_replaced_working_directory_is_rejected(self):
        self.register()
        self.cwd.rmdir()
        self.run_helper("resume-argv", "research", "--task", "Continue", success=False)
        replacement = self.base / "different worktree"
        replacement.mkdir()
        self.cwd.symlink_to(replacement, target_is_directory=True)
        self.run_helper("resume-argv", "research", "--task", "Continue", success=False)

    def test_atomic_failure_preserves_record_and_removes_temporary_file(self):
        original = self.register()
        before = self.record_path().read_bytes()
        original["checkpoint"] = "Updated"
        with agents.store_open(str(self.store)) as fd:
            with patch.object(agents.os, "replace", side_effect=OSError("synthetic failure")):
                with self.assertRaises(OSError):
                    agents.write_record(fd, original)
        self.assertEqual(self.record_path().read_bytes(), before)
        self.assertEqual(list(self.store.iterdir()), [self.record_path()])

    def test_concurrent_registration_has_one_winner(self):
        command = self.command("register", "research", "--tool", "zcode", "--session-id",
                               ZCODE_ID, "--cwd", str(self.cwd))
        processes = [subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE) for _ in range(2)]
        outputs = [process.communicate(timeout=10) for process in processes]
        self.assertEqual(sorted(process.returncode for process in processes), [0, 1])
        for process, (stdout, stderr) in zip(processes, outputs):
            if process.returncode == 0:
                self.assertEqual(json.loads(stdout)["session_id"], ZCODE_ID)
                self.assertEqual(stderr, "")
            else:
                self.assertEqual(stdout, "")
        self.assertEqual(self.run_helper("status", "research")["session_id"], ZCODE_ID)

    def test_native_existence_is_not_a_record_assertion(self):
        record = self.register()
        self.assertEqual(record["resume_evidence"], "")
        self.assertNotIn("verified", record)
        with self.assertRaises(ValueError):
            agents.resume_command(record, "\0")
        with self.assertRaises(ValueError):
            agents.resume_command(record, " ")


if __name__ == "__main__":
    unittest.main()
