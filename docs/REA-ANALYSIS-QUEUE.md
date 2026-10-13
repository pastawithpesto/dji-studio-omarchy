# REA analysis queue

`tools/rea_analysis_queue.py` is a Linux research CLI. It uses only the Python
standard library. It does not implement application behavior or execute vendor
code. The queue runs one function job at a time and preserves each attempt.
Read [the REA workflow](REA-WORKFLOW.md) before new analysis.

## Commands

```sh
python tools/rea_analysis_queue.py run /absolute/manifest.json --output /absolute/queue
python tools/rea_analysis_queue.py report --output /absolute/queue
python tools/rea_analysis_queue.py tree-hash /absolute/owned-rea/dist
```

`run` first checks the complete binary hash and saved input hashes. It checks each
byte witness against the original file. It then reuses a sealed matching result
or reads matching saved evidence. It makes no live REA call by default.
`--allow-live` permits a live call only with the explicit grant described below.
A partial saved dossier remains partial. It does not cause an automatic import.

Exit codes for `run`: `0` means all jobs are `evidence_ready`; `2` means at least
one job is `partial`; `1` means a job failed or the queue could not run.
`report` checks retained attempt artifacts and shows all attempts. It checks
current inputs separately. An absent or changed original source does not erase a
historical result. Its current verification is `failed_or_unavailable`.
Report mode never starts REA. Exit `0` means the historical report was read;
it does not mean that current inputs or all jobs passed.

The manifest is sealed on the first run. Resume uses the same manifest and output
directory. Use a new directory for a changed source, target, tool pin or grant.
A file lock prevents simultaneous writers to one queue. It does not reserve a
machine-wide analysis slot. Obtain the project resource grant separately.

## Saved evidence manifest

The following example uses placeholders. Replace each placeholder with an
observed value. All input paths must be absolute.

```json
{
  "schema_version": 1,
  "queue_id": "owned-function-study",
  "max_input_bytes": 67108864,
  "jobs": [
    {
      "id": "callback",
      "binary": {
        "path": "/absolute/original.dll",
        "sha256": "COMPLETE_SOURCE_SHA256",
        "build": "1.0.0.30839"
      },
      "address": "0x180001010",
      "producer": {
        "rea_commit": null,
        "rea_version": "6.4.0",
        "mcp_server_version": "6.4.0",
        "provider": {
          "id": "ghidra",
          "name": "Ghidra",
          "version": "12.1.4"
        },
        "analysis_profile_digest": "OBSERVED_PROFILE_SHA256"
      },
      "saved_evidence": [
        {
          "path": "/absolute/function-DOSSIER.json",
          "sha256": "RAW_DOSSIER_FILE_SHA256"
        }
      ],
      "byte_witnesses": [
        {
          "address": "0x180001010",
          "file_offset": 1040,
          "hex": "90c3",
          "provenance": "Exact original-byte and mapping record location"
        }
      ]
    }
  ]
}
```

A saved producer commit or MCP version can be `null` when the record does not
establish it. Do not substitute the current runner identity for an unknown saved
identity. The manifest supplies producer provenance. It does not authenticate a
historical REA installation. The byte witness example is illustrative, not a
claim about the function at the example address.

The adapter reads plain REA Evidence, the full CLI output envelope, MCP text
content, or `evidence_bundle.records` in a REA snapshot. If an MCP record contains
text and structured evidence, both must agree. There must be exactly one matching
`analyze_function` record in a selected input. The exact procedure selector,
complete subject hash, provider, analysis profile digest and resolved entry must
match the job. A wrong pin fails. A nonmatching saved query remains a recorded
probe failure. The queue preserves its raw input.

The queue checks each supplied byte sequence at its exact original-file offset.
It checks that witness address ranges lie inside the supplied inclusive function
body ranges. It does not derive the address-to-file mapping. `mapping_status`
remains `supplied_provenance`. Independent review must check that mapping and its
source record. The witness can come from original file bytes or a pinned provider
observation; state which one in `provenance`.

## Coverage

`evidence_ready` requires nonempty pseudocode, nonempty assembly, consistent
available function-body ranges, and matching witnesses for the whole claimed
body. A known bad-data or decompilation-failure marker makes pseudocode partial.
Other warnings and limitations remain in the report. The assembly check confirms
that the dossier contains assembly. It does not prove instruction decoding,
control flow, recovered types or the correctness of pseudocode.

`partial` preserves a matching dossier with missing required evidence. `failed`
preserves an input failure, unsupported result, command failure, timeout, output
limit or identity mismatch. Successful and partial attempts resume without a new
command while all pins and retained artifacts still match. Failed attempts retry
in a new attempt directory. A missing sealed record is an interrupted attempt.
Report mode lists it. A later run creates a new attempt.

Counts cover only the explicit manifest addresses. Duplicate binary/address jobs
are rejected. The tool does not infer whole-DLL coverage, decompile callers or
callees automatically, resolve alias equivalence, or approve behavior contracts.
The report keeps independent behavior review `pending` and runtime parity
`unverified`.

## Live runner and grant

Use a separate owned installation of the newest official upstream REA. Fetch and
record its current commit before new analysis. Verify its actual CLI help and
Ghidra configuration. Pin a job's profile from a matching current observation.
Do not guess a new profile from an older package version. If discovery produces
an unexpected profile, preserve the failed attempt. Review the observed identity
and use a new manifest and queue directory with the corrected pin.

Add these top-level fields to permit the live adapter:

```json
{
  "runner": {
    "argv": ["/absolute/node", "/absolute/owned-rea/scripts/rea.mjs"],
    "repository": "/absolute/owned-rea",
    "rea_commit": "FULL_40_HEX_UPSTREAM_COMMIT",
    "rea_version": "6.4.0",
    "files": [
      {"path": "/absolute/node", "sha256": "NODE_FILE_SHA256"},
      {"path": "/absolute/owned-rea/scripts/rea.mjs", "sha256": "ENTRY_FILE_SHA256"}
    ],
    "runtime_tree": {
      "path": "/absolute/owned-rea/dist",
      "sha256": "TREE_HASH_FROM_THE_QUEUE_COMMAND"
    },
    "environment": {
      "GHIDRA_INSTALL_DIR": "/absolute/ghidra",
      "JAVA_HOME": "/absolute/jdk"
    }
  },
  "resource_grant": {
    "allow_fresh_import": true,
    "authorization": "Exact user instruction or resource-grant bus record",
    "job_ids": ["callback"],
    "timeout_seconds": 180,
    "max_output_bytes": 16777216,
    "address_space_mb": 8192,
    "cpu_seconds": 180
  }
}
```

The numeric example is not a resource authorization or a recommended setting.
Use the granted values. `address_space_mb` is virtual address space per process.
`cpu_seconds` is CPU time per process. These OS limits do not cap the combined
resident memory or CPU time of all descendants. `max_output_bytes` bounds the
combined retained stdout and stderr. It does not cap temporary project storage.
Set and verify the JVM heap limit separately with the supported configuration.
Use an external resource monitor when the grant needs total resident memory.

The runner check verifies the repository commit, clean tracked source, package
version, executable and entry-file hashes, and the named runtime tree. It checks
these pins before and after a successful call. The tree hash includes file names
and complete file hashes; symbolic links are rejected. It does not pin installed
Node dependencies outside that tree, Ghidra/JDK files, or the host. Record those
identities in the evidence packet. This is a bounded runner check, not complete
attestation of all executable bytes. Never publish credentials in environment
values; the queue records the configured environment in `command.json`.

The live job's expected REA commit and package version must match the runner.
The adapter runs the actual current command:

```text
REA_ARGV function ORIGINAL_PATH --procedure=ADDRESS --provider=ghidra
  --snapshot OWNED_ATTEMPT_SNAPSHOT --format json --full-output
```

The current CLI rejects the equals form of the global format option. The adapter
uses separate `--format` and `json` arguments. Each CLI call owns and closes its
session. A snapshot is optional:

```json
"snapshot": {"path": "/absolute/saved-snapshot.json", "sha256": "RAW_SNAPSHOT_SHA256"}
```

The queue copies the pinned snapshot into its attempt. REA can update that copy.
It never passes the original saved snapshot for mutation. REA can fall back to a
new import when a snapshot cannot satisfy the request. Thus a live call always
needs explicit fresh-import authorization. The mode is
`live_cli_snapshot_or_import`; the queue does not infer a speedup or assert that
an import occurred. Read the retained REA output and provider observations.

## Attempt records and cancellation

Each attempt has a new `jobs/JOB_ID/NNNNNN` directory. It preserves the job,
raw saved inputs, probe errors, selected evidence and the sealed result record.
Live attempts also retain the exact command, raw stdout/stderr, copied snapshot,
process outcome and process cleanup observations. Files in the artifact index
become read-only at sealing. This is an additive record convention; it is not
protection against a privileged host user. Tool scratch directories remain
outside the sealed artifact index.

Resume verifies seals and all artifact hashes. It also binds selected saved
Evidence to the retained raw file hash in the manifest. Selected live Evidence
must match retained stdout. Recomputed local seals alone cannot replace a pinned
saved record. The REA evidence ID is checked for shape and preserved. The queue
does not implement REA's full semantic evidence-ID authentication or RFC 8785
profile validation. A manifest pin and a source-byte match do not supply
independent behavioral approval.

The queue uses Linux child-subreaper adoption to track detached REA providers.
It records each owned PID and its process start time. At timeout, output limit,
normal completion or operator interruption, it sends TERM and then KILL after a
bounded grace period. It checks PID/start-time identity before each signal and
reaps adopted children. Cleanup has its own bounded interval after the command
deadline. `process-cleanup.json` records surviving processes. Survivors make the
command fail. Abrupt SIGKILL or host loss can leave an unsealed attempt; external
resource ownership and recovery still apply. Do not signal a peer process.

Each completed queue run writes a new `reports/NNNNNN.json` evidence index.
Historical report mode reads the records without changing them. Correct a
published report with a new additive report. Keep raw failures and prior records.
No benchmark acceptance or default performance optimization is claimed.

## Checks

```sh
python -m unittest discover -s tests -p test_rea_analysis_queue.py -v
```

The tests use synthetic bytes and synthetic child processes. They check saved
reuse, current source and output pins, malformed evidence, partial results,
local-seal forgery, historical reporting, exclusive locks, bounded pipes,
detached-child cleanup and operator interruption. Real REA integration and
independent review are separate gates. No test executes a vendor DLL.
