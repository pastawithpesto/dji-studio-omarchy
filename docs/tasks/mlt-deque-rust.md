# Original MLT deque Rust task

Owner: @pastawithpesto. Author: luna-a-1.

Implement the 25 approved `mlt_deque_` APIs in Rust. Preserve their exact original names, normal-return calculations, slot bits, bounds, status values, ordering, and payload lifetime. Keep this work in the assigned four-file scope.

## Scope

- `src/mlt/deque.rs`
- `tests/mlt_deque.rs`
- `tests/fixtures/mlt/deque/**`
- `docs/tasks/mlt-deque-rust.md`

Do not edit `src/mlt.rs` or `src/lib.rs`. Do not implement properties, cache, pool, or tokeniser APIs in this task.

## Evidence and limits

The original source is MLT build 1.0.0.30839, SHA-256 `59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c`. Reuse the sealed property-container research packet and exact independent review `REVIEW.json` SHA-256 `0d37a6244d9a923c3a1fbf1bd8917dde83479362be3df5653ade171a4640076a`.

The review approves all 25 deque APIs for their original normal-return branches and same-kind typed operations. Stored cursor and count are qwords. Exported count and index values use the signed low dword. Integer pushes initialize four payload bytes, and integer reads consume four bytes. Other upper slot bytes are undefined for mixed-kind reads. Pointer and double reads use eight bytes. Pointer ownership and callbacks are not established.

Tagged Rust entries and explicit safe allocation/type errors are independent safety adaptations. They do not claim C prototype, Windows ABI, callback reentrancy, foreign-pointer lifetime, malformed inner `Impl`, or exception parity. The implementation must not invent those contracts or return success for unsupported cases.

Root is preparing original-DLL deque operation sequence fixtures through Wine. Until those arrive, use tests derived from the approved static contracts. Compare the reference fixtures before requesting final review.

## Plan and completion checks

1. Reserve this exact scope in a draft PR and require a current successful PR watchdog result before source edits.
2. Implement the approved Rust behavior and document any identifier adaptation with its original API name and source location.
3. Add contract tests and reference fixtures. Validate the module standalone, then run focused formatting, debug, release, and Clippy checks.
4. Compare the candidate against the original-DLL fixtures. Record exact commands, results, evidence hashes, and limits.
5. Request independent review of the exact candidate. Keep the PR in draft until review and required milestone verification finish.

Author completion means the bounded deque Rust implementation, checks, and reference comparison are complete. It does not mean full MLT DLL, Windows, GPU, camera, UI, project, or ABI parity. The wider property-container audit remains unfinished.
