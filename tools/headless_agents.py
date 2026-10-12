#!/usr/bin/env python3
"""Record native session IDs and print resume arguments on Linux."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import sys
import uuid


UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
IDS = {"zcode": re.compile("sess_" + UUID), "dsh": re.compile("session-" + UUID)}
MODES = ("plan", "build", "edit", "yolo")
FIELDS = {"schema", "name", "tool", "session_id", "cwd", "mode", "patch",
          "created_utc", "updated_utc", "checkpoint", "resume_evidence"}
MAX_RECORD = 8192


def short_text(value):
    if not isinstance(value, str) or len(value) > 500:
        raise ValueError("metadata text must have at most 500 characters")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError("metadata text must be one line without control characters")
    return value


def name_check(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", value):
        raise ValueError("name must use 1 to 64 lower-case letters, digits, _ or -")
    return value


def canonical_path(value, directory=True):
    if not isinstance(value, str) or not Path(value).is_absolute():
        raise ValueError("an absolute path is required")
    path = Path(value).resolve(strict=True)
    if not (path.is_dir() if directory else path.is_file()):
        raise ValueError("path has the wrong file type")
    return str(path)


def validate(record):
    if not isinstance(record, dict) or record.keys() != FIELDS:
        raise ValueError("invalid session record fields")
    if type(record["schema"]) is not int or record["schema"] != 1:
        raise ValueError("unsupported session record schema")
    name_check(record["name"])
    tool = record["tool"]
    if not isinstance(tool, str) or tool not in IDS:
        raise ValueError("unsupported tool")
    if not isinstance(record["session_id"], str) or not IDS[tool].fullmatch(record["session_id"]):
        raise ValueError("session ID must have the current native UUID format")
    if canonical_path(record["cwd"]) != record["cwd"]:
        raise ValueError("recorded working directory has changed")
    if tool == "zcode":
        if record["mode"] not in MODES or record["patch"] != "":
            raise ValueError("invalid Zcode options")
    else:
        if record["mode"] != "":
            raise ValueError("DSH has no Zcode permission mode")
        if record["patch"] != "" and canonical_path(record["patch"], False) != record["patch"]:
            raise ValueError("recorded DSH patch path has changed")
    for field in ("created_utc", "updated_utc"):
        value = record[field]
        if not isinstance(value, str) or not value.endswith("+00:00"):
            raise ValueError("record time must be UTC")
        datetime.fromisoformat(value)
    short_text(record["checkpoint"])
    short_text(record["resume_evidence"])
    return record


def private_owned(info, directory=False):
    correct_type = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if not correct_type or info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise ValueError("session store must be private and owned by the current user")
    if not directory and info.st_nlink != 1:
        raise ValueError("session record must not have hard links")


@contextmanager
def store_open(value, create=False):
    """Open each directory without following links, then lock the store."""
    path = Path(value)
    if not path.is_absolute() or path == Path("/") or ".." in path.parts:
        raise ValueError("store must be an absolute directory without ..")
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    fd = os.open("/", flags)
    try:
        for index, part in enumerate(path.parts[1:]):
            final = index == len(path.parts) - 2
            if final and create:
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                except FileExistsError:
                    pass
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        private_owned(os.fstat(fd), directory=True)
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield fd
    finally:
        os.close(fd)


def read_record(fd, name):
    path = name_check(name) + ".json"
    record_fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                        dir_fd=fd)
    with os.fdopen(record_fd, "rb") as stream:
        private_owned(os.fstat(stream.fileno()))
        data = stream.read(MAX_RECORD + 1)
    if len(data) > MAX_RECORD:
        raise ValueError("session record is too large")
    try:
        record = json.loads(data)
    except (ValueError, UnicodeError, RecursionError):
        raise ValueError("session record is not valid JSON") from None
    validate(record)
    if record["name"] != name:
        raise ValueError("session record name does not match its file")
    return record


def write_record(fd, record):
    validate(record)
    data = (json.dumps(record, ensure_ascii=True, sort_keys=True) + "\n").encode()
    if len(data) > MAX_RECORD:
        raise ValueError("session record is too large")
    temporary = ".record-" + str(uuid.uuid4())
    temp_fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                      0o600, dir_fd=fd)
    try:
        with os.fdopen(temp_fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, record["name"] + ".json", src_dir_fd=fd, dst_dir_fd=fd)
        os.fsync(fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=fd)
        except FileNotFoundError:
            pass


def resume_command(record, task, json_output=False):
    validate(record)
    if not isinstance(task, str) or not task.strip() or "\0" in task:
        raise ValueError("a non-empty task without NUL is required")
    if record["tool"] == "zcode":
        argv = ["zcode", "--cwd", record["cwd"], "--mode", record["mode"],
                "--resume", record["session_id"], "--prompt", task]
    else:
        argv = ["dsh", "--profile", "headless"]
        if record["patch"]:
            argv.extend(["--patch", record["patch"]])
        argv.extend(["--session-id", record["session_id"]])
        if json_output:
            argv.append("--json")
        argv.extend(["--", task])
    if json_output and record["tool"] == "zcode":
        argv.append("--json")
    return {"cwd": record["cwd"], "argv": argv}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--store", required=True, help="private external session record directory")
    commands = parser.add_subparsers(dest="command", required=True)
    register = commands.add_parser("register", help="record an existing native session ID")
    register.add_argument("name")
    register.add_argument("--tool", choices=IDS, required=True)
    register.add_argument("--session-id", required=True)
    register.add_argument("--cwd", required=True)
    register.add_argument("--mode", choices=MODES, default=None)
    register.add_argument("--patch", default="")
    register.add_argument("--resume-evidence", default="", help="reference to a successful native resume")
    commands.add_parser("status", help="show one metadata record").add_argument("name")
    checkpoint = commands.add_parser("checkpoint", help="save a short task handoff")
    checkpoint.add_argument("name")
    checkpoint.add_argument("--text", required=True)
    checkpoint.add_argument("--resume-evidence", default=None)
    resume = commands.add_parser("resume-argv", help="print arguments; do not run the native CLI")
    resume.add_argument("name")
    resume.add_argument("--task", required=True, help="DSH also accepts - to read task stdin")
    resume.add_argument("--json-output", action="store_true", help="native JSON output can contain private reasoning")
    args = parser.parse_args()
    try:
        name_check(args.name)
        with store_open(args.store, create=args.command == "register") as fd:
            if args.command == "register":
                try:
                    os.stat(args.name + ".json", dir_fd=fd, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    raise ValueError("record already exists; use a new name for a new session")
                if args.tool == "dsh" and args.mode is not None:
                    raise ValueError("--mode applies only to Zcode")
                now = datetime.now(timezone.utc).isoformat()
                record = {"schema": 1, "name": args.name, "tool": args.tool,
                          "session_id": args.session_id, "cwd": canonical_path(args.cwd),
                          "mode": (args.mode or "plan") if args.tool == "zcode" else "",
                          "patch": canonical_path(args.patch, False) if args.patch else "",
                          "created_utc": now, "updated_utc": now, "checkpoint": "",
                          "resume_evidence": args.resume_evidence}
                write_record(fd, record)
                result = record
            else:
                record = read_record(fd, args.name)
                if args.command == "checkpoint":
                    record["checkpoint"] = short_text(args.text)
                    if args.resume_evidence is not None:
                        record["resume_evidence"] = short_text(args.resume_evidence)
                    record["updated_utc"] = datetime.now(timezone.utc).isoformat()
                    write_record(fd, record)
                result = resume_command(record, args.task, args.json_output) if args.command == "resume-argv" else record
        print(json.dumps(result, ensure_ascii=True, sort_keys=True))
    except (OSError, ValueError, TypeError):
        print("headless_agents: invalid arguments, record, or private store; no model was run", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
