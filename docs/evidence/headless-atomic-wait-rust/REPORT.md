# Atomic-wait timeout Rust candidate report

Task PR45 on branch `work/headless-atomic-wait-rust-20261012`. Owner:
pastawithpesto. Rust author: GLM-5.3-Flash in a persisted Zcode headless
session. This report states source facts, the roles of the independent
research and review parties, the implemented candidate, and its limits.

## Original source and names (pinned)

Original file `msvcp140_atomic_wait.dll`, DJI Studio build 1.0.0.30839,
57,376 bytes, SHA-256
`ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.

| Original export | Ordinal | VA | File offset | Bytes | Body SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `__std_atomic_wait_get_deadline` | 11 | `0x1800015c0` | `0x9c0` | 33 | `91a621460251e107081a5c4abe58a32f74745cd2b6d93cc8fca49a9dca158b88` |
| `__std_atomic_wait_get_remaining_timeout` | 12 | `0x1800015f0` | `0x9f0` | 56 | `2090187ba92fcec6d04afdfdf1e278feaeb834ad6bef76ad6b7f1c62370516ad` |

Both calls resolve through the PE import slot at `0x1800050d0` to
`KERNEL32.dll!GetTickCount64` at call sites `0x1800015d2` and `0x180001604`.
The remaining-timeout body compares against the immediate `0x337f9800`
(864000000). The export address table slots for ordinals 11 and 12 are at
`0x180006660` and `0x180006664`. The two bodies do not overlap and are not
contiguous; the 15-byte gap `0x15e1..0x15f0` holds `0xcc` fill bytes.

## Evidence provenance (roles kept separate)

- DSH researcher produced `DSH-FINDINGS.md` (SHA-256
  `ecb83d11d0fea9a406a2b99055f81c8ef6785cfba6f062937bf4ccd2466c293a`)
  and the additive `DSH-CORRECTION-R1.md` (SHA-256
  `6216e596ea34b262a38499e3002d11fcf00e0d59288ad61d9925acb073086d18`).
  The corrections fix the export address table roles, the return-width
  test, and the non-contiguous bodies. The original findings stay sealed
  and unchanged.
- Independent Sol reviewer (`/root/sol61_atomic_contract`) performed the
  original-byte contract review, approved the corrected DSH contract in
  `DSH-R1-APPROVAL.md`, and verified the saved evidence with the latest
  owned tool in `LATEST-RESTORE-REVIEW.md`.
- The latest-tool verification used REA upstream and owned commit
  `e4d3e1399d9cd4932653e7015a1bf8589e56029d`, package and server 6.4.0,
  Ghidra 12.1.4, heap 768M, run `7ee81e3a-a59e-4b88-b7bf-b5a112fea43e`.
  It separated the two cached dossier replays (new evidence IDs
  `ev_283ae45a360b3f84643b1a9bee12b19c04bc7775f171e26f181b213960f4b597`
  and `ev_dda368976eaf3dbaefc8b4fadd82a9a94b7fb1445f3ec8f93406404fe2d3723a`)
  from two fresh uncached complete body reads (evidence IDs
  `ev_48a7b709ac9087965e997936bb23d572d78a5b9d85300eae635fb3105e01a9a0`
  and `ev_53de07bd265eccc7c5842600bb699a4f8dde5b9e4027d21b71b2f7a7927aa679`)
  that match the original source bytes exactly.
- This Rust author performed none of the original-byte, provider, or
  DSH checks. The copied records in this directory are root's sealed
  copies. All nine files match `selected-evidence-manifest.json`; this
  author rehashed them and changed none of them.

## Implemented API (independent Rust design)

The formal original C++ parameter and return declarations are unknown.
These signatures are an independent Rust API that models the observed
machine results. They claim no Windows ABI.

- `pub fn __std_atomic_wait_get_deadline(input: u64, clock: impl FnMut() -> u64) -> u64`
- `pub fn __std_atomic_wait_get_remaining_timeout(deadline: u64, clock: impl FnMut() -> u64) -> u64`

Both return the observed `RAX` bits as `u64`. The caller supplies a
clock as an `FnMut() -> u64` closure, which the function samples once on
each finite path and never on a sentinel path. Sentinel inputs return
`u64::MAX` for the deadline function and `0x0000_0000_FFFF_FFFF` for the
remaining function. Finite inputs sample exactly once. The deadline
function wraps with `wrapping_add`. The remaining function uses an
unsigned comparison, returns 0 at or above the deadline with equality
included, and clamps the unsigned difference at `REMAINING_TIMEOUT_CAP`
(`0x337F_9800`), the only new named constant. No remaining result sets a
bit above bit 31. The module adds no wait loop, clock origin, OS clock,
trait, or runtime integration, and no callbacks beyond the supplied
clock.

## Candidate checks (exact results)

Toolchain: system rustc 1.98.1, rustfmt 1.9.0, `Cargo.lock` unchanged.

- `rustfmt --edition 2024 --check src/atomic_wait.rs src/lib.rs
  tests/atomic_wait.rs`: clean.
- Focused `cargo test --test atomic_wait` with external target directory:
  10 passed, 0 failed, 0 ignored.
- Full `cargo test --locked`: all 31 reported test targets pass, 285 test
  cases passed, 0 failed, 0 ignored. No unrelated file was edited.

Test coverage: the 11 pinned reference vectors from
`docs/evidence/atomic-wait-timeouts/reference-model-results.txt` with
per-vector clock-call counts; sentinel paths with zero clock samples and
pinned result bits; finite paths with exactly one sample and recorded
side effects; wrapping to the sentinel and through zero; unsigned
high-bit comparisons; expired and equal deadlines including a finite zero
deadline with a large clock value; cap at one below, equal, and one above
plus huge differences; and a no-bit-above-31 property. All expectations
are pinned hex literals or pinned call counts. None is computed by the
implementation under test.

## Source state

Before edits this session fetched origin and read all nine open PR claim
bodies. Main was `8b147cadd1b92ff52b30cde995429cb04f85eb17`, an ancestor
of this branch head `7f57ef2b7ccc0c3ee53de16e842f0561542e1a9d`. PR45 was
a draft with passing claims check run 38265168354, job 114865394580. No
other open PR claims a path in this task scope. The candidate commit is
prepared on this branch only. No push, merge, or PR edit was made.

## Limits

- No Windows execution, vendor execution, or timing observation. The
  synthetic vectors and instruction pins do not establish runtime or
  application parity.
- No formal C++ declaration, parameter type, return type, or signedness.
- No wait-loop, wakeup, caller, reentrancy, or whole-DLL claim. The
  packed `.rdata` record roles remain unknown per correction R1.
- The clock is caller-supplied. This module defines no Linux clock,
  epoch, unit, or suspend mapping. The millisecond unit and 10-day cap
  value come from the separately cited Microsoft `GetTickCount64`
  documentation, not from the DLL bytes.
- Independent review of this exact candidate commit and separate
  milestone verification are still required before any authorized merge.
