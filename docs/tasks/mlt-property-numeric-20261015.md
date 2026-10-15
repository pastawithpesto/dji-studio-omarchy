# Implement the numeric MLT property getters

Owner: `pastawithpesto`.
Code author: GPT-6 Astra, High.

Implement the supported numeric branches of the original
`mlt_property_get_double` and `mlt_property_get_int` as safe Rust adapters.
Reuse the reviewed property-container contract and original instruction bytes.
Preserve original function names. Describe the borrowed Rust representation as
an independent interface, not the original C ABI.

## File scope

- `src/mlt.rs`
- `src/mlt/property.rs`
- `tests/mlt_property.rs`
- `tests/fixtures/mlt/property/**`
- `docs/tasks/mlt-property-numeric-20261015.md`
- `docs/evidence/mlt-property-numeric-20261015/**`

## Plan

1. Wait for a successful draft PR claim check.
2. Pin the original DLL, two routines and existing approved contract.
3. Specify flag precedence, numeric values and null data fallthrough.
4. Specify a supported float-to-integer conversion domain.
5. Obtain independent Sol High review of the adapter contract before code edits.
6. Implement the supported branches in Rust.
7. Register the property module in `src/mlt.rs`.
8. Add independent oracle and conversion-boundary tests.
9. Run focused tests and the application language check.
10. Obtain independent Sol High code review and Astra High verification.

## Completion check and limits

Tests must cover the different getter precedence orders and the low-dword reads
from integer slots. They must cover null data fallthrough and conversion limits.
Unsupported string parsing and unresolved conversion cases must return explicit
errors. Do not invent an original error policy or return a success stub.

The evidence must identify which behavior follows original instructions and
which behavior is a safe adapter decision. Original-DLL runtime comparison is
not available in the current saved numeric-property records. Keep that limit
explicit. Do not claim complete MLT or Windows parity.

`src/lib.rs` is owned by PR 45. Do not change it. Top-level library integration
is separate from this bounded module implementation.

## Source checkpoint

- Base: fresh main `d922d46337150db102cef675073cfa392ef92bbc`.
- Worktree: `/home/violence/Work/dji-mlt-property-numeric-20261015`.
- Branch: `feat/mlt-property-numeric-20261015`.
- Main is an ancestor of this task branch.

## Progress

Plan only. Contract review and implementation are pending.
