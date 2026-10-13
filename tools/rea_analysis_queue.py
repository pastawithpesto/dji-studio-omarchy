#!/usr/bin/env python3
"""Run a sequential, source-pinned REA research queue. No vendor code is run."""
from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import resource
import selectors
import signal
import subprocess
import sys
import time
from contextlib import contextmanager


class QueueError(Exception):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
                      allow_nan=False).encode("utf-8")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def require(condition, message):
    if not condition:
        raise QueueError(message)


def string(value, label):
    require(isinstance(value, str) and value and "\0" not in value, f"Invalid {label}")
    return value


def sha(value, label):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value),
            f"Invalid {label} SHA-256")
    return value


def address(value):
    require(isinstance(value, str) and re.fullmatch(r"0x[0-9a-fA-F]+", value),
            "Function address must be explicit hexadecimal")
    return int(value, 16)


def absolute(value):
    path = Path(string(value, "path"))
    require(path.is_absolute(), "Paths must be absolute")
    return path


def integer(value, label, minimum=1, maximum=2**63-1):
    require(type(value) is int and minimum <= value <= maximum, f"Invalid {label}")
    return value


def number(value, label, minimum, maximum):
    require(type(value) in (int, float) and math.isfinite(value)
            and minimum <= value <= maximum, f"Invalid {label}")
    return value


def load_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    try:
        return json.loads(data, object_pairs_hook=pairs,
                          parse_constant=lambda value: (_ for _ in ()).throw(
                              QueueError(f"Invalid JSON constant: {value}")))
    except (ValueError, UnicodeError) as exc:
        raise QueueError(f"Invalid JSON: {exc}") from exc


def read_bounded(path, limit):
    with Path(path).open("rb") as stream:
        data = stream.read(limit + 1)
    require(len(data) <= limit, f"Input exceeds byte limit: {path}")
    return data


def write_new(path, data):
    with Path(path).open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    Path(path).chmod(0o444)


def write_json(path, value):
    write_new(path, canonical(value) + b"\n")


def producer_identity(value):
    require(isinstance(value, dict), "Missing producer identity")
    for field in ("rea_version",):
        string(value.get(field), field)
    commit = value.get("rea_commit")
    require(commit is None or isinstance(commit, str) and
            re.fullmatch(r"[0-9a-f]{40}", commit), "Invalid producer REA commit")
    server = value.get("mcp_server_version")
    require(server is None or isinstance(server, str) and server, "Invalid MCP version")
    provider = value.get("provider")
    require(isinstance(provider, dict) and set(provider) == {"id", "name", "version"},
            "Invalid provider identity")
    require(provider["id"] == "ghidra", "This adapter supports Ghidra only")
    for item in provider.values():
        string(item, "provider identity")
    sha(value.get("analysis_profile_digest"), "analysis profile")


def validate_manifest(manifest):
    require(isinstance(manifest, dict) and type(manifest.get("schema_version")) is int and manifest["schema_version"] == 1,
            "Expected manifest schema_version 1")
    string(manifest.get("queue_id"), "queue ID")
    jobs = manifest.get("jobs")
    require(isinstance(jobs, list) and jobs, "Manifest has no jobs")
    seen_ids, seen_targets = set(), set()
    for job in jobs:
        require(isinstance(job, dict), "Invalid job")
        ident = job.get("id")
        require(isinstance(ident, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}", ident),
                "Invalid job ID")
        require(ident not in seen_ids, "Duplicate job ID")
        seen_ids.add(ident)
        binary = job.get("binary")
        require(isinstance(binary, dict), "Missing binary identity")
        absolute(binary.get("path"))
        sha(binary.get("sha256"), "binary")
        string(binary.get("build"), "reference build")
        target = (binary["sha256"], address(job.get("address")))
        require(target not in seen_targets, "Duplicate binary/function target")
        seen_targets.add(target)
        producer_identity(job.get("producer"))
        require(isinstance(job.get("saved_evidence", []), list), "Invalid saved evidence")
        for pin in job.get("saved_evidence", []):
            require(isinstance(pin, dict), "Invalid saved input pin")
            absolute(pin.get("path"))
            sha(pin.get("sha256"), "saved evidence")
        require(isinstance(job.get("byte_witnesses", []), list), "Invalid byte witnesses")
        for witness in job.get("byte_witnesses", []):
            require(isinstance(witness, dict), "Invalid byte witness")
            address(witness.get("address"))
            integer(witness.get("file_offset"), "witness file offset", 0)
            require(isinstance(witness.get("hex"), str) and re.fullmatch(
                r"(?:[0-9a-fA-F]{2})+", witness["hex"]), "Invalid witness bytes")
            string(witness.get("provenance"), "witness provenance")
        if "snapshot" in job:
            require(isinstance(job["snapshot"], dict), "Invalid snapshot pin")
            absolute(job["snapshot"].get("path"))
            sha(job["snapshot"].get("sha256"), "snapshot")
    integer(manifest.get("max_input_bytes", 64 * 1024 * 1024), "input byte limit", 1,
            1024 * 1024 * 1024)
    return manifest


def evidence_records(value):
    """Accept observed CLI, MCP and REA snapshot envelopes."""
    require(isinstance(value, dict), "Evidence must be an object")
    if "ok" in value and "data" in value:
        require(value["ok"] is True, "REA returned a failure envelope")
        return evidence_records(value["data"])
    if "content" in value:
        require(not value.get("isError"), "REA returned an MCP error")
        records = []
        require(isinstance(value["content"], list), "Invalid MCP content")
        for content in value["content"]:
            require(isinstance(content, dict), "Invalid MCP content item")
            if content.get("type") == "text":
                require(isinstance(content.get("text"), str), "Invalid MCP text")
                records.extend(evidence_records(load_json(content["text"])))
        require(records, "MCP envelope has no evidence")
        if "structuredContent" in value:
            structured = evidence_records(value["structuredContent"])
            require(canonical(structured) == canonical(records),
                    "MCP text and structured evidence disagree")
        return records
    if "evidence_bundle" in value:
        require(isinstance(value["evidence_bundle"], dict), "Invalid evidence bundle")
        records = value["evidence_bundle"].get("records")
        require(isinstance(records, list) and all(isinstance(record, dict) for record in records),
                "Snapshot has invalid evidence records")
        return records
    require("evidence_id" in value and "normalized_result" in value,
            "No supported REA evidence envelope")
    return [value]


def select_evidence(value, job):
    candidates = [record for record in evidence_records(value)
                  if record.get("operation") == "analyze_function" and
                  record.get("parameters") == {"procedure": job["address"]}]
    require(len(candidates) == 1, "Expected exactly one matching function evidence record")
    return candidates[0]


def check_evidence(evidence, job):
    require(isinstance(evidence, dict), "Invalid evidence record")
    producer = job["producer"]
    require(evidence.get("operation") == "analyze_function" and
            evidence.get("parameters") == {"procedure": job["address"]},
            "Output operation or function selector does not match")
    subject = evidence.get("subject") or {}
    require(isinstance(subject, dict) and isinstance(subject.get("digest", {}), dict),
            "Invalid evidence subject")
    require(subject.get("digest", {}).get("sha256") == job["binary"]["sha256"],
            "Output source identity does not match")
    require(evidence.get("provider") == producer["provider"],
            "Output provider identity does not match")
    profile = evidence.get("analysis_profile") or {}
    require(isinstance(profile, dict), "Invalid evidence analysis profile")
    require(profile.get("digest") == producer["analysis_profile_digest"] and
            profile.get("provider") == producer["provider"],
            "Output analysis profile does not match")
    require(isinstance(evidence.get("evidence_id"), str) and re.fullmatch(
        r"ev_[0-9a-f]{64}", evidence["evidence_id"]), "Invalid REA evidence ID")
    result = evidence.get("normalized_result")
    require(isinstance(result, dict), "Output has no function dossier")
    procedure = result.get("procedure") or {}
    require(isinstance(procedure, dict), "Invalid output procedure")
    require(address(procedure.get("address")) == address(job["address"]),
            "Resolved function entry does not match")
    body = procedure.get("body") or {}
    require(isinstance(body, dict), "Invalid function body")
    ranges = body.get("ranges", [])
    require(isinstance(ranges, list), "Invalid function body ranges")
    intervals = []
    for item in ranges:
        require(isinstance(item, dict), "Invalid function body range")
        start, end = address(item.get("start")), address(item.get("end"))
        require(start <= end, "Invalid inclusive body range")
        intervals.append((start, end))
    intervals.sort()
    require(all(intervals[i-1][1] < intervals[i][0] for i in range(1, len(intervals))),
            "Overlapping body ranges")
    body_bytes = sum(end - start + 1 for start, end in intervals)
    body_complete = bool(intervals) and body.get("available") is True and \
        body.get("contains_entry") is True and body.get("total_bytes") == body_bytes and \
        any(start <= address(job["address"]) <= end for start, end in intervals)
    pseudo = result.get("pseudocode")
    assembly = result.get("assembly")
    pseudo_ok = isinstance(pseudo, str) and bool(pseudo.strip())
    assembly_ok = isinstance(assembly, list) and bool(assembly) and all(
        isinstance(line, str) and bool(line.strip()) for line in assembly)
    warnings = []
    for container in (evidence, result):
        limits = container.get("limitations", [])
        require(isinstance(limits, list) and all(isinstance(x, str) for x in limits),
                "Invalid evidence limitations")
        warnings.extend(limits)
    if pseudo_ok and re.search(r"halt_baddata|BAD_DATA|decompilation failed|unable to decompile",
                               pseudo, re.IGNORECASE):
        pseudo_ok = False
        warnings.append("Pseudocode contains a bad-data or decompilation-failure marker.")
    witnesses = job.get("byte_witnesses", [])
    covered = []
    for witness in witnesses:
        start = address(witness["address"])
        end = start + len(bytes.fromhex(witness["hex"])) - 1
        require(any(a <= start <= end <= b for a, b in intervals),
                "Byte witness lies outside the claimed function body")
        covered.append((start, end))
    merged = []
    for start, end in sorted(covered):
        if merged and start <= merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
        else:
            merged.append((start, end))
    witness_bytes = sum(end-start+1 for start, end in merged)
    coverage = {"pseudocode": pseudo_ok, "assembly": assembly_ok,
                "body_ranges": body_complete, "body_bytes": body_bytes,
                "witness_bytes": witness_bytes, "source_byte_match": bool(witnesses),
                "whole_body_witness": body_complete and witness_bytes == body_bytes,
                "mapping_status": "supplied_provenance" if witnesses else "unavailable",
                "independent_behavior_review": "pending", "runtime_parity": "unverified"}
    ready = pseudo_ok and assembly_ok and body_complete and coverage["whole_body_witness"]
    return {"status": "evidence_ready" if ready else "partial", "coverage": coverage,
            "evidence_id": evidence["evidence_id"], "limitations": list(dict.fromkeys(warnings)),
            "producer": producer}


def check_inputs(job, limit):
    binary = job["binary"]
    require(sha_file(binary["path"]) == binary["sha256"], "Binary SHA-256 does not match")
    with Path(binary["path"]).open("rb") as stream:
        for witness in job.get("byte_witnesses", []):
            expected = bytes.fromhex(witness["hex"])
            stream.seek(witness["file_offset"])
            require(stream.read(len(expected)) == expected, "Source byte witness does not match")
    for pin in job.get("saved_evidence", []) + ([job["snapshot"]] if "snapshot" in job else []):
        require(digest(read_bounded(pin["path"], limit)) == pin["sha256"],
                f"Saved input SHA-256 does not match: {pin['path']}")


def tree_digest(path):
    """Pin runnable build files. Names and bytes form the tree identity."""
    path = absolute(str(path))
    require(path.is_dir(), "Runtime tree is not a directory")
    h = hashlib.sha256()
    for file in sorted(path.rglob("*")):
        require(not file.is_symlink(), "Runtime tree contains a symbolic link")
        if file.is_file():
            relative = file.relative_to(path).as_posix().encode()
            h.update(len(relative).to_bytes(8, "big"))
            h.update(relative)
            h.update(bytes.fromhex(sha_file(file)))
    return h.hexdigest()


def check_runner(runner):
    require(isinstance(runner, dict), "No live REA runner is configured")
    argv = runner.get("argv")
    require(isinstance(argv, list) and argv, "Invalid runner argv")
    for arg in argv:
        string(arg, "runner argument")
    require(absolute(argv[0]).is_file(), "Runner executable is not a file")
    commit = runner.get("rea_commit")
    require(isinstance(commit, str) and re.fullmatch(r"[0-9a-f]{40}", commit),
            "Live runner requires a complete REA commit")
    repo = absolute(runner.get("repository"))
    proc = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                          capture_output=True, timeout=10, check=False)
    require(proc.returncode == 0 and proc.stdout.decode().strip() == commit,
            "Runner repository commit does not match")
    proc = subprocess.run(["git", "-C", str(repo), "diff", "HEAD", "--exit-code"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    require(proc.returncode == 0, "Runner tracked source has changes")
    package = load_json(read_bounded(repo / "package.json", 1024 * 1024))
    require(package.get("version") == runner.get("rea_version"), "Runner package version mismatch")
    pins = runner.get("files")
    require(isinstance(pins, list) and pins, "Runner has no executable file pins")
    pin_paths = set()
    for pin in pins:
        require(isinstance(pin, dict), "Invalid runner file pin")
        pin_paths.add(str(absolute(pin.get("path"))))
        require(sha_file(pin["path"]) == sha(pin.get("sha256"), "runner file"),
                "Runner file hash mismatch")
    require(argv[0] in pin_paths and all(arg in pin_paths for arg in argv[1:] if
            Path(arg).is_absolute()), "Runner executable or entry file is not pinned")
    tree = runner.get("runtime_tree") or {}
    require(isinstance(tree, dict), "Invalid runtime tree pin")
    require(tree_digest(tree.get("path")) == sha(tree.get("sha256"), "runtime tree"),
            "Runner runtime tree hash mismatch")
    env = runner.get("environment", {})
    require(isinstance(env, dict) and all(isinstance(k, str) and isinstance(v, str)
            and "\0" not in k + v and "=" not in k for k, v in env.items()),
            "Invalid runner environment")
    require(not ({"HOME", "TMPDIR"} & env.keys()), "Runner cannot replace owned HOME or TMPDIR")
    return runner


def check_grant(grant, job):
    require(isinstance(grant, dict) and grant.get("allow_fresh_import") is True,
            "Live REA can import a source. An explicit fresh-import grant is required")
    string(grant.get("authorization"), "import authorization record")
    require(job["id"] in grant.get("job_ids", []), "Job is outside the resource grant")
    number(grant.get("timeout_seconds"), "timeout", 0.05, 86400)
    integer(grant.get("max_output_bytes"), "output limit", 1, 1024 * 1024 * 1024)
    integer(grant.get("address_space_mb"), "address-space limit", 64, 1048576)
    integer(grant.get("cpu_seconds"), "CPU limit", 1, 86400)


def process_identity(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return {"start_time": fields[19], "state": fields[0]}
    except (OSError, IndexError):
        return None


def process_children(pid):
    children = set()
    for task in Path(f"/proc/{pid}/task").glob("*/children"):
        try:
            children.update(int(item) for item in task.read_text().split())
        except OSError:
            continue
    return children


def run_process(command, directory, env, limits):
    """Bound pipes and kill only the process group created for this attempt."""
    def constrain():
        ceiling = limits["address_space_mb"] * 1024 * 1024
        resource.setrlimit(resource.RLIMIT_AS, (ceiling, ceiling))
        cpu = limits["cpu_seconds"]
        resource.setrlimit(resource.RLIMIT_CPU, (cpu, cpu))
    started = time.monotonic()
    status = "exited"
    total = 0
    libc = ctypes.CDLL(None, use_errno=True)
    previous_subreaper = ctypes.c_int()
    require(libc.prctl(37, ctypes.byref(previous_subreaper), 0, 0, 0) == 0 and
            libc.prctl(36, 1, 0, 0, 0) == 0, "Linux child subreaper is unavailable")
    baseline_children = process_children(os.getpid())
    owned = {}
    proc = None
    previous_handlers = {}
    cleanup = {}

    def track():
        pending = process_children(os.getpid()) - baseline_children
        if proc is not None:
            pending.add(proc.pid)
        pending.update(owned)
        scanned = set()
        while pending:
            pid = pending.pop()
            if pid in scanned:
                continue
            scanned.add(pid)
            identity = process_identity(pid)
            if identity is None:
                continue
            if pid in owned and owned[pid] != identity["start_time"]:
                continue
            owned[pid] = identity["start_time"]
            pending.update(process_children(pid))

    def alive(pid):
        identity = process_identity(pid)
        return identity is not None and identity["start_time"] == owned[pid] and \
            identity["state"] != "Z"

    def stop(signum):
        for pid in list(owned):
            identity = process_identity(pid)
            if identity is not None and identity["start_time"] == owned[pid]:
                try:
                    os.kill(pid, signum)
                except ProcessLookupError:
                    pass

    def interrupted(signum, _frame):
        raise KeyboardInterrupt(f"Received signal {signum}")

    try:
        for signum in (signal.SIGTERM, signal.SIGHUP):
            previous_handlers[signum] = signal.signal(signum, interrupted)
        proc = subprocess.Popen(command, cwd=directory, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, start_new_session=True, preexec_fn=constrain)
        track()
        with selectors.DefaultSelector() as selector, \
                (directory / "stdout.raw").open("xb") as stdout, \
                (directory / "stderr.raw").open("xb") as stderr:
            selector.register(proc.stdout, selectors.EVENT_READ, stdout)
            selector.register(proc.stderr, selectors.EVENT_READ, stderr)
            while selector.get_map():
                track()
                remaining = limits["timeout_seconds"] - (time.monotonic() - started)
                if remaining <= 0:
                    status = "timeout"
                    break
                for key, _ in selector.select(min(remaining, 0.05)):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    budget = limits["max_output_bytes"] - total
                    key.data.write(chunk[:budget])
                    total += min(len(chunk), budget)
                    if len(chunk) > budget:
                        status = "output_limit"
                        break
                if status != "exited":
                    break
            if status == "exited":
                while proc.poll() is None:
                    track()
                    if time.monotonic() - started >= limits["timeout_seconds"]:
                        status = "timeout"
                        break
                    time.sleep(0.02)
    finally:
        # Adoption keeps detached providers under this owner when the CLI exits.
        # Never signal a PID whose /proc start time no longer matches.
        for signum in previous_handlers:
            signal.signal(signum, signal.SIG_IGN)
        track()
        stop(signal.SIGTERM)
        grace_deadline = time.monotonic() + 1
        while any(alive(pid) for pid in owned) and time.monotonic() < grace_deadline:
            time.sleep(0.02)
            track()
        stop(signal.SIGKILL)
        if proc is not None:
            proc.wait(timeout=5)
            proc.stdout.close()
            proc.stderr.close()
        reap_deadline = time.monotonic() + 1
        while time.monotonic() < reap_deadline:
            track()
            for pid in owned:
                if proc is None or pid != proc.pid:
                    try:
                        os.waitpid(pid, os.WNOHANG)
                    except ChildProcessError:
                        pass
            survivors = [pid for pid in owned if alive(pid)]
            if not survivors:
                break
            time.sleep(0.02)
        cleanup = {"owned_processes": [{"pid": pid, "start_time": start}
                                       for pid, start in sorted(owned.items())],
                   "surviving_processes": [pid for pid in owned if alive(pid)],
                   "method": "Linux subreaper, tracked descendants, PID/start-time checked TERM then KILL"}
        write_json(directory / "process-cleanup.json", cleanup)
        libc.prctl(36, previous_subreaper.value, 0, 0, 0)
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
    if cleanup["surviving_processes"]:
        status = "cleanup_failed"
    return {"process_status": status, "returncode": proc.returncode,
            "wall_seconds": time.monotonic() - started, "output_bytes": total,
            "cleanup": cleanup,
            "resource_scope": "per-process address space and CPU; owned descendants deadline plus bounded cleanup"}



@contextmanager
def queue_lock(output):
    output.mkdir(parents=True, exist_ok=True)
    require(not output.is_symlink(), "Queue directory must not be a symbolic link")
    descriptor = os.open(output / ".lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise QueueError("Queue is already locked") from exc
        yield
    finally:
        os.close(descriptor)


def new_attempt(output, ident):
    jobs = output / "jobs"
    jobs.mkdir(exist_ok=True)
    require(not jobs.is_symlink(), "Jobs directory must not be a symbolic link")
    base = jobs / ident
    base.mkdir(exist_ok=True)
    require(not base.is_symlink(), "Job directory must not be a symbolic link")
    numbers = [int(item.name) for item in base.iterdir() if item.is_dir() and
               re.fullmatch(r"[0-9]{6}", item.name)]
    attempt = base / f"{max(numbers, default=0)+1:06d}"
    attempt.mkdir()
    return attempt


def seal_attempt(directory, record):
    for path in directory.iterdir():
        if path.is_file():
            path.chmod(0o444)
    record["artifacts"] = {path.name: sha_file(path) for path in sorted(directory.iterdir())
                           if path.is_file()}
    write_json(directory / "record.json", record)
    write_new(directory / "record.sha256", (sha_file(directory / "record.json") + "\n").encode())


def validate_origin(directory, record, job, evidence, limit):
    """Bind selected output to retained raw evidence, not mutable local seals."""
    if record.get("mode") == "saved_evidence":
        matches = []
        for index, pin in enumerate(job.get("saved_evidence", [])):
            raw_path = directory / f"saved-{index:04d}.raw"
            require(raw_path.is_file(), "Cached saved input is missing")
            raw = read_bounded(raw_path, limit)
            require(digest(raw) == pin["sha256"], "Cached saved input pin does not match")
            try:
                candidate = select_evidence(load_json(raw), job)
                matches.append(canonical(candidate) == canonical(evidence))
            except (QueueError, KeyError, TypeError):
                continue
        require(any(matches), "Cached selected evidence differs from the pinned saved raw input")
    elif record.get("mode") == "live_cli_snapshot_or_import":
        raw = read_bounded(directory / "stdout.raw", limit)
        require(canonical(select_evidence(load_json(raw), job)) == canonical(evidence),
                "Cached selected evidence differs from retained REA stdout")
    else:
        raise QueueError("Cached attempt has an unsupported origin mode")


def previous_result(output, job, manifest_hash, limit):
    base = output / "jobs" / job["id"]
    if not base.exists():
        return None
    for directory in sorted(base.iterdir(), reverse=True):
        if not directory.is_dir() or not (directory / "record.json").exists():
            continue
        require(not directory.is_symlink(), "Attempt directory is a symbolic link")
        record_raw = read_bounded(directory / "record.json", 16 * 1024 * 1024)
        require(digest(record_raw) == (directory / "record.sha256").read_text().strip(),
                "Attempt record hash mismatch")
        record = load_json(record_raw)
        require(record.get("manifest_sha256") == manifest_hash and record.get("job_id") == job["id"],
                "Attempt manifest or job identity mismatch")
        for name, expected in record.get("artifacts", {}).items():
            require(Path(name).name == name and sha_file(directory / name) == expected,
                    "Cached attempt artifact hash mismatch")
        if record.get("status") in ("evidence_ready", "partial"):
            evidence = select_evidence(load_json(read_bounded(directory / "evidence.json", limit)), job)
            validate_origin(directory, record, job, evidence, limit)
            result = check_evidence(evidence, job)
            require(all(record.get(key) == value for key, value in result.items()),
                    "Cached result coverage does not match its raw evidence")
            return {**record, "attempt": str(directory), "resumed": True}
    return None


def execute_job(manifest, job, output, manifest_hash, live):
    limit = manifest.get("max_input_bytes", 64 * 1024 * 1024)
    try:
        check_inputs(job, limit)
        prior = previous_result(output, job, manifest_hash, limit)
        if prior:
            return prior
        preflight_error = None
    except (QueueError, OSError, KeyError, TypeError) as exc:
        preflight_error = str(exc)
    directory = new_attempt(output, job["id"])
    record = {"manifest_sha256": manifest_hash, "job_id": job["id"],
              "binary": job["binary"], "address": job["address"],
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
              "status": "failed", "resumed": False, "input_verification": "failed_or_unavailable"}
    try:
        require(preflight_error is None, preflight_error)
        record["input_verification"] = "verified"
        write_json(directory / "job.json", job)
        selected = None
        probes = []
        for index, pin in enumerate(job.get("saved_evidence", [])):
            raw = read_bounded(pin["path"], limit)
            require(digest(raw) == pin["sha256"], "Saved input changed during copy")
            write_new(directory / f"saved-{index:04d}.raw", raw)
            try:
                candidate = select_evidence(load_json(raw), job)
                result = check_evidence(candidate, job)
                if selected is None or result["status"] == "evidence_ready":
                    selected = (candidate, result)
            except (QueueError, KeyError, TypeError) as exc:
                probes.append({"path": pin["path"], "error": str(exc)})
        write_json(directory / "saved-probes.json", probes)
        if selected is not None:
            evidence, result = selected
            record["mode"] = "saved_evidence"
        else:
            require(live, "No matching saved evidence. Live analysis was not requested")
            runner = check_runner(manifest.get("runner"))
            grant = manifest.get("resource_grant")
            check_grant(grant, job)
            require(runner["rea_commit"] == job["producer"]["rea_commit"] and
                    runner["rea_version"] == job["producer"]["rea_version"],
                    "Live runner and expected producer identity differ")
            snapshot = directory / "snapshot.json"
            if "snapshot" in job:
                raw = read_bounded(job["snapshot"]["path"], limit)
                require(digest(raw) == job["snapshot"]["sha256"], "Snapshot changed during copy")
                parsed = load_json(raw)
                require(parsed.get("target", {}).get("sha256") == job["binary"]["sha256"],
                        "Snapshot source identity does not match")
                write_new(directory / "snapshot-input.raw", raw)
                snapshot.write_bytes(raw)
            command = runner["argv"] + ["function", job["binary"]["path"],
                f"--procedure={job['address']}", "--provider=ghidra",
                "--snapshot", str(snapshot), "--format", "json", "--full-output"]
            env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"),
                   "HOME": str(directory / "home"), "TMPDIR": str(directory / "tmp")}
            (directory / "home").mkdir()
            (directory / "tmp").mkdir()
            env.update(runner.get("environment", {}))
            write_json(directory / "command.json", {"argv": command, "environment": env,
                       "runner": runner, "resource_grant": grant})
            outcome = run_process(command, directory, env, grant)
            record.update(outcome)
            require(outcome["process_status"] == "exited" and outcome["returncode"] == 0,
                    f"REA process failed: {outcome['process_status']}, exit {outcome['returncode']}")
            check_runner(runner)
            evidence = select_evidence(load_json(read_bounded(directory / "stdout.raw", limit)), job)
            result = check_evidence(evidence, job)
            record["mode"] = "live_cli_snapshot_or_import"
            record["runner"] = runner
        check_inputs(job, limit)
        write_json(directory / "evidence.json", evidence)
        record.update(result)
    except (QueueError, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        record["error"] = str(exc)
    except KeyboardInterrupt:
        record["error"] = "Interrupted by operator"
        seal_attempt(directory, record)
        raise
    seal_attempt(directory, record)
    return {**record, "attempt": str(directory)}


def run_queue(manifest_path, output, live=False):
    raw = read_bounded(manifest_path, 16 * 1024 * 1024)
    manifest = validate_manifest(load_json(raw))
    identity = digest(canonical(manifest))
    output = Path(output).absolute()
    with queue_lock(output):
        pin = output / "manifest.json"
        if pin.exists():
            require(pin.read_bytes() == canonical(manifest) + b"\n",
                    "Queue manifest has changed. Use a new queue directory")
        else:
            write_json(pin, manifest)
        results = [execute_job(manifest, job, output, identity, live) for job in manifest["jobs"]]
        report = {"schema_version": 1, "queue_id": manifest["queue_id"],
                  "manifest_sha256": identity, "results": results,
                  "counts": {status: sum(r["status"] == status for r in results)
                             for status in ("evidence_ready", "partial", "failed")},
                  "limits": ["Coverage counts only the manifest function addresses.",
                             "Saved producer identity is a supplied provenance pin.",
                             "Byte address-to-file mappings require independent review.",
                             "This report does not establish native behavior or Windows parity."]}
        reports = output / "reports"
        reports.mkdir(exist_ok=True)
        require(not reports.is_symlink(), "Reports directory is a symbolic link")
        existing = list(reports.glob("*.json"))
        report_path = reports / f"{len(existing)+1:06d}.json"
        write_json(report_path, report)
        report["report_path"] = str(report_path)
        return report


def historical_report(output):
    """Inspect all sealed attempts without granting new work."""
    output = Path(output).absolute()
    with queue_lock(output):
        manifest = validate_manifest(load_json(read_bounded(output / "manifest.json", 16 * 1024 * 1024)))
        identity = digest(canonical(manifest))
        limit = manifest.get("max_input_bytes", 64 * 1024 * 1024)
        results = []
        for job in manifest["jobs"]:
            try:
                check_inputs(job, limit)
                current = {"status": "verified"}
            except (QueueError, OSError, KeyError, TypeError) as exc:
                current = {"status": "failed_or_unavailable", "error": str(exc)}
            base = output / "jobs" / job["id"]
            attempts = []
            for directory in sorted(base.iterdir()) if base.exists() else []:
                if not directory.is_dir():
                    continue
                require(not directory.is_symlink(), "Attempt directory is a symbolic link")
                if not (directory / "record.json").exists():
                    attempts.append({"attempt": str(directory), "status": "interrupted_unsealed"})
                    continue
                raw = read_bounded(directory / "record.json", 16 * 1024 * 1024)
                require(digest(raw) == (directory / "record.sha256").read_text().strip(),
                        "Attempt record hash mismatch")
                record = load_json(raw)
                require(record.get("manifest_sha256") == identity and record.get("job_id") == job["id"],
                        "Attempt manifest or job identity mismatch")
                for name, expected in record.get("artifacts", {}).items():
                    require(Path(name).name == name and sha_file(directory / name) == expected,
                            "Cached attempt artifact hash mismatch")
                if record.get("status") in ("evidence_ready", "partial"):
                    evidence = select_evidence(load_json(read_bounded(directory / "evidence.json", limit)), job)
                    validate_origin(directory, record, job, evidence, limit)
                    result = check_evidence(evidence, job)
                    require(all(record.get(key) == value for key, value in result.items()),
                            "Cached result coverage does not match its raw evidence")
                attempts.append({**record, "attempt": str(directory)})
            results.append({"job_id": job["id"], "current_input_verification": current,
                            "attempts": attempts})
        return {"schema_version": 1, "queue_id": manifest["queue_id"],
                "manifest_sha256": identity, "mode": "historical_report", "results": results,
                "limits": ["Attempt statuses are historical observations.",
                           "Current input verification is reported separately.",
                           "No REA command, import or vendor code runs in report mode."]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="Run or resume a pinned sequential queue")
    run.add_argument("manifest", type=Path)
    run.add_argument("--output", required=True, type=Path)
    run.add_argument("--allow-live", action="store_true")
    report = sub.add_parser("report", help="Inspect historical attempts and current input availability")
    report.add_argument("--output", required=True, type=Path)
    tree = sub.add_parser("tree-hash", help="Hash a REA dist runtime directory")
    tree.add_argument("path", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "tree-hash":
            print(tree_digest(args.path))
            return 0
        if args.command == "report":
            print(json.dumps(historical_report(args.output), indent=2, ensure_ascii=False))
            return 0
        report = run_queue(args.manifest, args.output, args.allow_live)
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 1 if report["counts"]["failed"] else 2 if report["counts"]["partial"] else 0
    except KeyboardInterrupt:
        print("Queue interrupted; retained attempts remain available", file=sys.stderr)
        return 130
    except (QueueError, OSError, KeyError, TypeError, ValueError) as exc:
        print(f"Queue error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
