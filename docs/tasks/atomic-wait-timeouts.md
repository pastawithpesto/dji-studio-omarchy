# Recover bounded atomic wait timeout behavior

Owner: @pastawithpesto
Author: Luna, routed as `luna-atomic-20261012`

## Task

Recover the bounded behavior of `__std_atomic_wait_get_deadline` and
`__std_atomic_wait_get_remaining_timeout` from the shipped MSVC runtime DLL.
Trace only the imports needed to explain these two exports.

Reference: DJI Studio 1.0.0.30839, `msvcp140_atomic_wait.dll`, 57,376 bytes,
SHA-256 `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.

## Method and completion record

Before analysis, the claims watchdog passed for candidate `4f5216c4aa984237dfd9929a615820bf98702582` (run [38214760856](https://github.com/pastawithpesto/dji-studio-omarchy/actions/runs/38214760856)). A fresh read of all 19 open PR claims found no path conflict. The first refreshed `origin/main` was `4a546957e4155aee38608a53b7388ef5a6feac48`; main then advanced to `ad90db13d7fff5745baa5ec84ff1b7c31a19ac35`. A normal merge commit (`82b411883ad920d61e171cd206ac2f90fd277b13`) appended that current main. This task record is introduced by this PR and was absent from the shared main base.

The source file's size and full hash matched before and after analysis. Independent GNU and LLVM PE inventories agree on the selected exports and imported `GetTickCount64` edge. One owned REA/Ghidra 12.1.4 baseline static capture supplies pseudocode, assembly, function body ranges, evidence IDs, and original-byte witnesses. An independent Python arithmetic model uses only explicit synthetic time values. It passes 11 static cases. The vendor DLL was not executed.

The bounded results, exact addresses and bytes, return-width evidence, model, and limits are in [`docs/evidence/atomic-wait-timeouts/REPORT.md`](../evidence/atomic-wait-timeouts/REPORT.md). The Microsoft `GetTickCount64` API citation is separate from observed target behavior. Formal C/C++ types are not claimed from Ghidra's inferred types.

## Source history and reservation

Repository: `pastawithpesto/dji-studio-omarchy`
Worktree: `/home/violence/Work/dji-atomic-wait-research-20261012`
Branch: `research/luna-atomic-wait-timeouts-20261012`
Initial published plan commit: `4e7caf7f7dd2a772db9f23302691db393e21507a`
Initial base: `54081edf52f23231500db222136eae0a681e6535`

An intermediate commit rebased the plan onto newer main and was force-pushed. A later normal merge (`f8617580ae0ad696343bb5805b8f17432e4518e3`) restored the original published plan commit as an ancestor. The branch first appended refreshed main by normal merge (`4f5216c4aa984237dfd9929a615820bf98702582`), then appended the latest main by the normal merge above. The evidence publication commit follows those merges. The earlier rebase and force-push remain part of this branch's history and are recorded here; they are not described as absent.

The source claim is limited to `docs/tasks/atomic-wait-timeouts.md` and
`docs/evidence/atomic-wait-timeouts/**`. This PR remains a draft for independent
review. There is no application implementation, merge, approval, whole-library
coverage, wait-wakeup, or Windows-equivalence claim.
