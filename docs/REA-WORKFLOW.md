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
2. Select at least three small DLLs that represent the intended workload. Freeze
   the DLL set and pair count N before measuring. Pin their complete hashes.
   Use N >= 5 measured baseline/candidate pairs per DLL. Alternate order to reduce
   order bias. Keep settings and workload
   equivalent within each pair. Record warm-ups separately. Do not discard slow
   runs or failures from the results.
3. Test fresh analysis and saved evidence inspection separately. Compare both
   methods on the same task. A cached retrieval is not a new decompilation.
   Use separate owned snapshots for fresh runs. State cache conditions and other
   host activity. Never flush peer caches or stop peer work to improve a score.
4. Declare identical pipeline boundaries before timing. Start before client
   startup and source verification. Stop after required output checks, report
   writes and owned-session cleanup. Record tool installation and harness
   preparation separately. Measure import, first analysis, retrieval and byte
   checks as stages. Record complete wall time, CPU, peak memory, failures and
   timeouts for every run. Report units and process scope. Linux wait4 CPU is
   user plus system seconds; ru_maxrss is a process/descendant maximum in KiB,
   not summed simultaneous memory. Measure total memory separately if the grant
   limits it. Verify heap limits separately from resident memory.
   Report every run and each DLL's median and range. Aggregate the sum of all
   selected DLLs' wall-time medians. Keep fresh-analysis and saved-inspection
   decisions separate. Never pool their timings.
5. Check the same required outputs, coverage, source bytes, provenance and
   warnings for every pair. Preserve raw pseudocode and assembly. Investigate
   differences rather than hiding them with normalization. Missing evidence,
   hash mismatches, unresolved output differences or weaker checks fail the gate.

## Accept, reject and discard

Use these default thresholds and decision order. A task owner may set different
limits and a noise rule in the recorded plan before the first run. Never change
the DLL set, pair count, limits or noise rule to rescue a result.

1. A correctness defect, new failure, new timeout or resource-grant breach
   rejects the optimization immediately, even when measurements are noisy.
   A failed baseline run makes performance comparison incomplete; preserve it.
2. Otherwise, missing required wall, CPU, memory, failure or verification data
   makes the decision inconclusive. The default noise rule also makes a mode
   inconclusive if any DLL's baseline or candidate wall-time sample has a median
   absolute deviation greater than 10% of its median. Record workload changes
   that make runs incomparable. Keep the baseline active for inconclusive data.
3. For complete comparable data that passes the declared noise rule, accept only if all checks
   pass and the sum of all selected per-DLL wall-time medians improves by at
   least 10%. Require at least ceil(0.8*N) strictly faster candidate pairs for
   each DLL. Ties do not count as wins. No DLL's wall-time median may regress by
   more than 5%. Each DLL's CPU and peak-memory medians may not regress by more
   than 10% against their corresponding baseline medians. Apply these limits
   separately for each tested mode. A threshold failure or no measurable gain
   rejects the optimization for that mode. Acceptance applies only to the tested
   targets, workload, mode, tool versions and resource limits.

After the decision:

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
