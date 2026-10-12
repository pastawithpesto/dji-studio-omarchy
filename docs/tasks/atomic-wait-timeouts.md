# Recover bounded atomic wait timeout behavior

Owner: @pastawithpesto
Author: Luna, routed as `luna-atomic-20261012`

## Task

Recover the bounded behavior of `__std_atomic_wait_get_deadline` and
`__std_atomic_wait_get_remaining_timeout` from the shipped MSVC runtime DLL.
Trace only the helpers and imports needed to support these two exports.

The reference is DJI Studio 1.0.0.30839:

- File: `msvcp140_atomic_wait.dll`
- Path: `/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/msvcp140_atomic_wait.dll`
- Size: 57376 bytes
- SHA-256: `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`

The declared source pin came with the assignment. Verify the complete file hash
before analysis and after analysis. Search for matching saved evidence before an
import. Use the newest official REA revision in an owned installation. Record its
commit, package version, running MCP server version, Ghidra version, and heap
limit. Use an exclusive, nonblocking Ghidra import lock only when a fresh import
is necessary.

## Method

Start binary analysis only after this PR's `claims` watchdog check passes. Keep
the original DLL and complete raw analysis local. Publish only the bounded
evidence required for review under `docs/evidence/atomic-wait-timeouts/`.

Record both exports, their aliases or thunks, body ranges, required helpers,
imports, pseudocode, assembly, and original-byte witnesses. Pin integer widths,
sentinels, overflow behavior, clamping, and time-source dependence to source
bytes. Build independent adapted models with explicit synthetic time inputs.
Do not execute the vendor DLL or infer Windows wait or thread wakeup behavior.

## Completion check

- Verify the assigned size and SHA-256 before and after analysis.
- Compare independent PE and LLVM export inventories.
- Record original-byte ranges for each bounded claim.
- Check pseudocode against assembly and source bytes.
- State supported widths, sentinels, overflow and clamp rules, and the time source.
- Run static model checks only against the recovered instruction behavior.
- Record unknowns and limits. Do not claim full DLL coverage or Windows equivalence.
- Request independent review of the exact evidence packet.

## Source reservation

Repository: `pastawithpesto/dji-studio-omarchy`
Worktree: `/home/violence/Work/dji-atomic-wait-research-20261012`
Branch: `research/luna-atomic-wait-timeouts-20261012`
Initial base and fresh remote main: `54081edf52f23231500db222136eae0a681e6535`
Checked: `2026-10-12T06:29:30Z`
Ancestry: fresh remote main is the initial base and an ancestor of the branch.
The new clone was clean before this plan was written.
