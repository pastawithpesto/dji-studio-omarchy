# Atomic-wait timeout Rust contract

Owner: pastawithpesto. DSH provides research in a persisted headless conversation.
GLM-5.3-Flash uses Zcode headless to author Rust after independent contract review.
Sol reviewers check the exact evidence and code candidate before authorized merge.

## Scope

- `src/lib.rs`
- `src/atomic_wait.rs`
- `tests/atomic_wait.rs`
- `docs/tasks/headless-atomic-wait-rust.md`
- `docs/evidence/headless-atomic-wait-rust/**`

Only reconstruct `__std_atomic_wait_get_deadline` and
`__std_atomic_wait_get_remaining_timeout` as pure functions with a supplied clock.
Preserve their original names. Do not add wait-loop, wakeup, clock-origin, Windows
ABI, application-integration, or runtime-equivalence claims.

## Evidence

Reuse the immutable `docs/evidence/atomic-wait-timeouts` packet. Original DJI
Studio build1.0.0.30839 `msvcp140_atomic_wait.dll` has SHA-256
`ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.
The two bodies start at VA `0x1800015c0` and `0x1800015f0`.
Independent source checks must confirm every claimed byte and arithmetic branch.
Use latest owned REA and retain exact source, tool, snapshot and evidence pins.
Label saved analysis reuse separately from fresh decompilation.

## Plan

1. Check current main, open claims, and this PR watchdog.
2. Verify and review the bounded DSH research contract.
3. Resume the same Zcode conversation with the approved contract and exact scope.
4. Implement sentinel short-circuits, wrapping add, unsigned comparison and cap.
5. Test independent reference vectors and clock-call counts.
6. Obtain independent code review and separate milestone verification.
7. Refresh the base and repeat affected checks/review before authorized merge.

## Initial source

Fresh main: `8b147cadd1b92ff52b30cde995429cb04f85eb17`.
Owned branch: `work/headless-atomic-wait-rust-20261012`.
Owned worktree: `/home/violence/Work/dji-headless-atomic-wait-rust-20261012`.
The user warns that the base changes. Recheck it before each source checkpoint.
