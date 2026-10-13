# Queue versus direct REA timing

The queue did not make this bounded task faster.
Fresh analysis took approximately the same time.
Saved evidence inspection took more time with the queue.
Both modes fail the frozen speed thresholds.
Keep the direct workflow as the baseline for this task.
The queue remains an experiment for evidence management and resume support.

Two GPT-6.1 Sol High agents ran separate workflows.
One used the reviewed queue. The other used direct REA calls.
Each mode has five pairs for each of three DLLs.
All 60 trials passed. All 30 pairs have exactly equal full Evidence objects.
Agent reasoning and token latency were excluded from the clocks.
This test measures scripted workflow processing.
It does not measure total agent productivity or full reverse engineering.

## Aggregate wall time

The aggregate is the sum of the three per-DLL medians.
It is not a pooled average or total experiment duration.
Fresh and saved results are separate.

| Mode | Direct REA (s) | Queue (s) | Queue change |
| --- | ---: | ---: | ---: |
| fresh | 70.739781 | 71.076944 | +0.48% more time |
| saved | 0.258335 | 0.569278 | +120.36% more time |

## Per-DLL measurements

Wall and CPU units are seconds. RSS units are MiB.
CPU includes owned workers and reaped descendants plus the common verifier.
Observer CPU is recorded separately in the JSON data.
RSS is the sampled sum of the monitor and observed owned descendants.
It can count shared pages more than once. It is not an exact physical peak.
The wait4 maximum-process RSS is recorded separately in KiB.

| Mode | DLL | Method | Wall median | Wall range | Wall MAD/median | CPU median | RSS median |
| --- | --- | --- | ---: | --- | ---: | ---: | ---: |
| fresh | ThumbnailProvider | manual | 27.971980 | 26.779542 to 51.235512 | 2.651% | 54.364925 | 1087.406 |
| fresh | ThumbnailProvider | queue | 28.540572 | 26.475902 to 30.553857 | 3.103% | 56.444190 | 1092.719 |
| fresh | crashpad_wer | manual | 17.669730 | 17.586002 to 20.630686 | 0.474% | 32.404555 | 1003.254 |
| fresh | crashpad_wer | queue | 18.523990 | 17.590675 to 19.247405 | 2.312% | 34.158414 | 1028.414 |
| fresh | bugly_extra_handler | manual | 25.098071 | 23.545033 to 26.458559 | 2.986% | 49.574433 | 1071.426 |
| fresh | bugly_extra_handler | queue | 24.012383 | 23.418708 to 25.174694 | 1.148% | 49.050624 | 1097.664 |
| saved | ThumbnailProvider | manual | 0.085506 | 0.085467 to 0.085726 | 0.045% | 0.070626 | 42.238 |
| saved | ThumbnailProvider | queue | 0.189161 | 0.188974 to 0.189943 | 0.099% | 0.161736 | 64.789 |
| saved | crashpad_wer | manual | 0.086387 | 0.086314 to 0.086555 | 0.063% | 0.069332 | 42.375 |
| saved | crashpad_wer | queue | 0.189894 | 0.189328 to 0.189966 | 0.038% | 0.162680 | 64.688 |
| saved | bugly_extra_handler | manual | 0.086443 | 0.086391 to 0.086564 | 0.060% | 0.070978 | 42.363 |
| saved | bugly_extra_handler | queue | 0.190223 | 0.189783 to 0.191117 | 0.064% | 0.165196 | 64.762 |

All wall samples pass the declared MAD/median noise limit of 10%.
The direct ThumbnailProvider run 020 took 51.235512 seconds.
It remains in the range and all calculations. No run was discarded or repeated.
The cause of this slow run is unknown.
The host was shared. Peer activity was not stopped or fully measured.

## Threshold result

Fresh queue wins were 3/5, 2/5 and 4/5 for ThumbnailProvider, crashpad_wer and
bugly_extra_handler respectively. The required count was 4/5 for every DLL.
The aggregate did not improve by the required 10%.
Fresh per-DLL wall, CPU and sampled RSS regression limits passed.
The fresh speed threshold result is rejection for this measured task.

Saved queue wins were 0/5 for every DLL.
Saved aggregate improvement, per-DLL wins, wall, CPU and sampled RSS limits failed.
The saved speed threshold result is rejection for this measured task.

Neither result authorizes default adoption.
The CLI combines import and first analysis in one stage.
Thus, this report does not attest full benchmark-policy stage compliance.
No merge, release or application milestone is claimed.

## Identical task and checks

Each fresh run makes one actual REA CLI function call:

```text
node REA/scripts/rea.mjs function ORIGINAL --procedure=ADDRESS --provider=ghidra --snapshot OWNED_ABSENT --format json --full-output
```

Each run has a new output directory and an absent owned snapshot.
The direct workflow reads the full function dossier.
It does not make redundant pseudocode, assembly or byte queries.
Saved mode gives both workflows the same frozen plain Evidence file.
No prior completed queue output is reused.
Thus, saved mode tests evidence inspection, not checkpoint resume.

Both methods verify the complete original SHA-256, function, operation, provider,
profile, full body ranges, source-byte witnesses, pseudocode, assembly and warnings.
The common verifier independently checks these records after each driver.
It also checks exact PE address mapping and whole declared body coverage.
The byte check reads the original file. It is not a new loaded-image byte query.
Full DLL hashes, addresses, body spans, offsets, byte lengths and hashes are in
[SPEC-PUBLIC.json](SPEC-PUBLIC.json).
The functions are DllCanUnloadNow in ThumbnailProvider and
OutOfProcessExceptionEventCallback in each other DLL.
The crashpad address is the resolved body, not its export thunk.
This covers one function per DLL. It does not establish full DLL coverage.

All paired raw Evidence objects, including pseudocode, assembly, provenance and
warning arrays, match exactly. Dictionary key order alone is canonicalized for
comparison hashes. Actual parsed objects were also compared directly.
The derived report objects have different auxiliary fields.
The direct report concatenates warning arrays and retains duplicate strings.
The queue report removes duplicate warning strings.
All unique warnings remain, and the full raw warning arrays are unchanged.
[ROOT-POSTCHECK.json](ROOT-POSTCHECK.json) records these differences for every pair.
No timed output was changed to resolve the difference.

## Tool, cache and resource conditions

REA commit: `f254f5ac2b804b353a711264bb178f43fdf07867`, package 6.4.0.
The direct CLI has no running MCP server, so fresh MCP version is null.
Ghidra version: 12.1.4. Observed JVM heap: `-Xmx768M` in every fresh run.
Queue commit: `4f8a94a71451da5c99e6b4335d99bb6b94eba4bc`.
The saved producer used REA package/MCP 6.4.0 and Ghidra 12.1.4.
Its upstream commit is unknown and remains null.
Fresh and saved profile digests are pinned separately in the spec.

The tool was latest upstream at freeze.
A newer upstream commit was fetched after all trials.
It was not built or measured. The result applies to the frozen tool commit.
Tool and filesystem caches were warm from preparation.
No peer caches, files, installations or sessions were changed.
A shared scheduler and existing import lock serialized all measured trials.
Only one native provider ran at a time.
No vendor DLL was executed.

The clock starts before driver startup, source verification and client startup.
It stops after output checks, report writes, common verification and owned cleanup.
Scheduler waits, installation, helper preparation and model reasoning are excluded.
The pipeline deadline was 210 seconds, and sampled aggregate RSS limit was 2 GiB.
Per-process address space and CPU limits were 64 GiB and 180 seconds.
Raw output limit was 16 MiB. The query timeout was 180 seconds.
All recorded limits passed. All return codes were zero.
No timeout, measured failure or surviving owned process was recorded.
Memory sampling was every 20 ms and can miss short peaks.
Native import and first analysis cannot be reported as separate timings.
Driver stages are retained in each measurement record.

## Preparation and review

Preparation was outside the timed trials.
Comparable totals for installation, driver preparation and agent setup were not captured.
Total agent start-to-delivery time was also not reliably captured.
Worker summaries show the measured worker lifecycle only.
They do not show total agent task time. Preparation history is recorded below.
Three earlier native warm-ups and eight final source/dossier checks were separate.
An initial saved-input check failed because the baseline expected plain Evidence,
while the input was an MCP wrapper. Both methods then received the same exact
plain Evidence extraction. The original wrapper and extraction proof remain local.
An initial fresh baseline check failed because its runtime digest ordering differed.
The baseline corrected the ordering before freeze and passed its regression check.
An early monitor scanned all processes and caused high observer cost.
It was replaced before freeze with owned-descendant sampling.
The initial helper, failed checks and corrected checks remain in the local archive.
These preparation failures are not measured samples.
No frozen code, tool or workload changed during the 60 trials.

Both agents independently recomputed the root results from all 60 records.
Each also checked the opposite workflow's recorded evidence.
The independent calculation reports are under manual-agent and queue-agent here.
Root recomputed all verification records and checked every frozen code/runtime pin.
Independent Sol review of the exact public candidate is a separate PR record.
Astra milestone verification and merge approval remain pending.

## Evidence and reproduction

[PLAN.json](PLAN.json) is an exact copy of the plan frozen before measurement.
[RESULTS.json](RESULTS.json) has every statistic, pair result and measurement hash.
The runs directory contains all 60 unchanged measurement records.
The original frozen helpers and two agent drivers are included at their original
relative paths. These are research tools. They do not change application code.
[SPEC-PUBLIC.json](SPEC-PUBLIC.json) removes body-byte payloads and supplies hashes.
It is a public derivative, not the executable private frozen spec.
The complete raw outputs, vendor originals, snapshots and original spec remain at
`/home/violence/Work/dji-queue-vs-manual-benchmark-20261012`.
The public packet contains no original DLL or full decompiled dossier.

To recompute numeric results, use a separate temporary directory.
Copy PLAN.json, analyze.py and the runs directory into it.
Write SPEC.json from the `spec` object in SPEC-PUBLIC.json.
The analyzer uses only the target IDs from that spec for numeric calculations.
Run `python analyze.py` and compare mode statistics and measurement hashes.
The new spec hash will differ from the private original. Do not claim hash identity.
Do not replace or edit the frozen original archive.

A new native experiment needs the pinned originals, saved dossiers and exact tools.
Prepare an owned installation, update local paths and obtain resource grants.
Freeze a new plan and spec before measurement.
Changed paths, tools or helpers describe a new experiment.

[ARTIFACTS.json](ARTIFACTS.json) pins each public packet file except itself.
[SOURCE-STATE.json](SOURCE-STATE.json) records source freshness and ownership.
