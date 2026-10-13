# Queue versus direct REA benchmark

The user requests two GPT-6.1 Sol High agents.
One uses the reviewed REA queue. The other uses the direct REA workflow.
Measure three small original DLLs with the same bounded function task.
Freeze five paired runs per DLL for fresh analysis and saved inspection.
Keep these modes separate. Alternate execution order.

## Scope

- docs/tasks/queue-vs-manual-benchmark.md
- docs/evidence/queue-vs-manual-benchmark/**

Root owns the public task and evidence packet.
Workers own separate local workflow drivers and raw output directories.
No queue or application source changes are in scope.
No vendor code execution, default optimization adoption, merge or release.

## Method

Pin the current upstream REA, queue commit, originals and function addresses.
Give both workers the same source and body-byte witnesses.
Use one actual REA function call for each fresh task.
Do not add redundant pseudocode or assembly calls to the direct baseline.
Saved mode gives both workers the same pinned saved dossier.
Each method verifies source, function, provider, profile, body bytes and warnings.
Each method preserves raw results and writes a report.

Write the frozen plan before measurements.
Use the same external wall, CPU and memory monitor for both methods.
Hold the existing import lock for native work.
Start before source verification and client startup.
Stop after checks, evidence packaging and owned-process cleanup.
Record tool installation, harness preparation and agent setup separately.
Preserve every failure, timeout and slow run.
Apply docs/REA-WORKFLOW.md acceptance and noise rules per mode.
Cross-check output equivalence and require independent result review.

## Result

All 60 frozen trials passed. All 30 paired full Evidence objects match exactly.
Fresh aggregate wall medians were 70.739781 seconds direct and 71.076944 seconds
with the queue. Saved aggregates were 0.258335 and 0.569278 seconds.
The queue fails the frozen speed thresholds in both modes.
Keep the direct workflow as the baseline for this measured task.
No default optimization is adopted. Queue source and application source are unchanged.

The [evidence packet](../evidence/queue-vs-manual-benchmark/README.md) has the plan,
all measurements, independent calculation reviews, source pins and limitations.
The test excludes model reasoning and token latency. It covers one function per DLL.
CLI import and first-analysis clocks are combined. Full policy-stage acceptance,
Astra milestone verification, merge and application parity remain unclaimed.
