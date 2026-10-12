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

## Progress

2026-10-12: Implemented `src/atomic_wait.rs` with the two exact export names
and added one module export to `src/lib.rs`. `tests/atomic_wait.rs` covers the
11 pinned reference vectors and the reviewed behavior classes. rustfmt passes
on the three claimed Rust files. Focused `cargo test --test atomic_wait`:
10 passed, 0 failed. Full locked `cargo test --locked`: 285 passed, 0 failed.
Base `8b147cadd1b92ff52b30cde995429cb04f85eb17` refetched and confirmed as an
ancestor of this branch before edits. PR45 claims watchdog passed on head
`7f57ef2b7ccc0c3ee53de16e842f0561542e1a9d` before edits, run 38265168354.
Record: `docs/evidence/headless-atomic-wait-rust/REPORT.md`. The candidate
commit stays on this branch. No push. Independent review of the exact commit
is the next gate.

2026-10-12 correction: prior candidate
`98708212e110f568e67569e955c47d4c4a2e239a` passed independent Sol checks with
no behavior defect: 10 focused tests and 17,283 original-instruction vectors
in debug and optimized builds, plus panic-clock sentinel checks. This
correction fixes an incorrect signedness remark in the
`remaining_treats_values_as_unsigned` test comment and clarifies the clock
and callback wording in `REPORT.md`. No function body, test expectation,
test count, dependency, or sealed record changed.
