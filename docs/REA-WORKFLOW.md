# REA workflow and benchmark gate

Read the project instructions and assigned scope first. Use the assigned GUI when
requested. Write comms and reports in English. Preserve original source strings.

## Tool and evidence requirements

Use the latest upstream REA from the [official repository](https://github.com/morluto/rea).
At task start and resume, fetch its default branch. Update only an owned
installation to the newest upstream commit before new analysis. Record that
commit, package version, running MCP server version, Ghidra version and settings.
Preserve peer installations, processes and sessions.

Pin the original build, complete source SHA-256 and requested function addresses.
Find matching saved evidence before an import. Keep evidence pinned to the tool
that produced it. Confirm compatibility before opening an older snapshot with a
newer tool. Reanalyze if a change affects the claim or compatibility is unknown.
Request required resource grants. Do not execute vendor DLLs for a timing test.

Decompile new or changed targets. Check relevant pseudocode against assembly and
original bytes. Preserve warnings, uncertain types and unresolved boundaries.
For saved evidence inspection, verify the complete source hash and claimed bytes
against pinned provider witnesses. Label reuse separately from new decompilation
and offline checks separately from verification of a newly loaded image.

## Candidate optimizations

These are experiments until they pass the benchmark gate below. They are not
unconditional instructions. Retain the last validated baseline until acceptance.

- Keep one owned session per DLL and batch the required function queries.
- Resolve thunks and export aliases. Query each distinct body once, then follow
  the actual callees needed for the assigned question.
- Inspect the full `analyze_function` dossier. In the previously tested interface,
  `normalized_result.pseudocode` and `normalized_result.assembly` contain the
  requested evidence. Test reuse of those fields instead of repeating
  `procedure_pseudo_code` and `procedure_assembly` queries. Request missing
  evidence when needed. Verify the current schema.
- Automate source hashes, byte checks, timings and evidence packaging. Keep
  uncertain ABI, types and behavior subject to manual and independent review.

## Mandatory benchmark before adoption

1. Reserve a bounded test and obtain required resource grants. Write a benchmark
   plan before measuring. Pin the baseline instructions, candidate instructions,
   tool identities, host, heap limits, source files, targets and output checks.
   Change one optimization at a time.
2. Select at least three small DLLs that represent the intended workload. Pin
   their complete hashes. Use at least five measured baseline/candidate pairs
   per DLL. Alternate order to reduce order bias. Keep settings and workload
   equivalent within each pair. Record warm-ups separately. Do not discard slow
   runs or failures from the results.
3. Test fresh analysis and saved evidence inspection separately. Compare both
   methods on the same task. A cached retrieval is not a new decompilation.
   Use separate owned snapshots for fresh runs. State cache conditions and other
   host activity. Never flush peer caches or stop peer work to improve a score.
4. Measure end-to-end wall time, including setup, required verification and
   reporting. Also record import, first analysis, retrieval, byte checks, CPU,
   peak memory, failures and timeouts when available. Report every run, each
   DLL's median and range, and the sum of the three per-DLL wall-time medians.
5. Check the same required outputs, coverage, source bytes, provenance and
   warnings for every pair. Preserve raw pseudocode and assembly. Investigate
   differences rather than hiding them with normalization. Missing evidence,
   hash mismatches, unresolved output differences or weaker checks fail the gate.

## Accept, reject and discard

Use these default thresholds. A task owner may set different limits in the
recorded plan before the first run. Never change limits to rescue a result.

- Accept only if all correctness checks pass, the sum of per-DLL wall-time
  medians improves by at least 10%, and the candidate is faster in at least four
  of five pairs for each DLL. No DLL's median may regress by more than 5%.
- Require no new failures or timeouts. CPU and peak memory must stay within the
  resource grant and may not regress by more than 10% against the corresponding
  baseline medians. Missing resource measurements leave that part unverified.
  Do not claim full acceptance until required measurements are available.
- A correctness defect, failure, resource breach or threshold failure rejects
  the optimization. No measurable gain also rejects it. If noise or missing
  data prevents a decision, mark it inconclusive and keep the baseline active.
- On rejection, stop using the candidate. Remove its directive from active
  instructions or mark it explicitly disabled with the benchmark record and
  reason. Restore the last validated baseline. Preserve rejected instructions,
  failed probes and sealed evidence as history. Do not erase the benchmark.
- Obtain independent review of the exact results and instruction change before
  making an accepted candidate the default. Record the decision, scope and tool
  identities. Revalidate after relevant upstream, Ghidra, settings or workload
  changes. A later regression disables the optimization until it passes again.

Only optional optimization directives are discarded. The latest upstream REA
requirement, source pins, byte verification, evidence preservation, English comms,
resource ownership and independent review remain mandatory.

## Benchmark record and historical limit

Save the plan, source hashes, tool commits and versions, exact commands, all raw
timings, output comparisons, warnings, failures, limits and acceptance decision.
Pin the resulting artifacts. Correct a sealed record with an additive report.
Link the record from the active instruction when adopting or disabling a rule.

The earlier local experiment used REA 6.4.0 and Ghidra 12.1.4 on three DLLs.
Saved dossier inspection took 7.7 to 9.9 times less wall time than fresh analysis.
A separate pseudocode request restarted the engine and reduced the snapshot
benefit. Those runs measured different processing paths, used only one fresh
run and two reuse runs per DLL, and ran on an uncontrolled host. They motivate
an experiment. They do not pass this gate or establish current upstream behavior.
The full local evidence is available from the maintainer; it is not in this clone.

See the [task and review scope](tasks/rea-benchmark-policy.md). Bounded export
analysis, speed measurements and static byte checks do not establish complete DLL
coverage, Windows behavior or application parity.
