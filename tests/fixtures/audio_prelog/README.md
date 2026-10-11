# Audio pre-log evidence and test scope

This module implements the approved bounded contract706, reviewed713, under
author grant714. Interface and capacity behavior are independent design;
operation widths/order are recovered static facts. Exact fixture bits use an
independent RNE analytic model. They are not observed Windows rounding or audio
parity. Typed i16 values are host values; byte decoding, sample rate, channels,
caller-result usage, log-library numerics and complete audio processing remain
outside this module.

Pinned source build1.0.0.30839: `audio_highlight.dll`, SHA256
`14c3f88484c3a0fe673fcf19494f3394aad102a7e220ba464520e127eda166e3`,
helper `FUN_180013780`. Saved assembly:
`glm-review/resumed-comms-20261010/audio-input-abi/FUN_180013780.asm`, SHA256
`8337e5d1253ce36e1817224c88e544d0dea308427ea9118c75a1ab16b6e99fe0`.
REA identity: `ev_c2f7589039a6e2606d54ebc1d73b4bdc64c3bca0358205ede4017d96a75829d6`.
Review713 reuses earlier independent verification of416 saved bytes, four
constants and the caller join; this author does not claim a fresh runtime or
REA check.

Controlling `glm-review/swarm-20261010-2154/audio-rust-api-contract/revision2/CONTRACT-V2.md`,
SHA256 `1f02cbf99aeae5617d323518b0dbc79e38c3e5b81423041702a33c3bd7f697bb`;
oracle manifest SHA256
`c5cef3ebac92f4ac7df0fdb2fa3b003fc706c30bb0125793b5720b99b3c120e5`.
Independent contract review:
`sol-reviewer-review/swarm-20261010-2154/audio-api-revision2/REVIEW.md`.
Code review and canonical integration are separate gates.

| Static fact | Original instruction/data location |
|---|---|
| Signed i16 read, exact f32 normalization | `1800137c0`/`180013859`; scale bits `38000000` at `18002d038` |
| Separate f32 square; input-order sequential f64 sum | `1800137de`, `1800137e6`, `1800137ed` and later unrolled lanes; tail `180013872..180013879` |
| f64 divide and sqrt | `1800138a9`, `1800138b9` |
| f32 RMS round then f64 widening | `1800138d2`, `1800138d6` |
| Binary64 threshold comparison | `1800138da`; exact bits `3ddb7cdfd9d7bdbb` at `18002d040` |
| Count0 skips both loops and stores | guards `180013797/18001379b`, `180013854/180013857`; count test `180013882` and branch `180013885` occur after both loops |
| Native sentinel, not a Rust dB return | load `1800138f3`, bits `c2c80000` at `18002d068`, return `180013900` |
| Negative-mean sqrt fallback | ordered `0 > mean` branch `1800138b4`; unreachable for valid i16/RNE domain, not a universal NaN filter |
| Deferred log and multiply | call `1800138e0 -> 180025ef2`, multiply `1800138e5`, ordinary return `1800138f2` |
| One caller uses16000, not a helper cap | load `180012e24`, output pointer `180012e2a`, call `180012e34` via thunk `1800019ba`, bytes `e9c11d0100` |

`fixtures.json` is copied byte-identical from
`glm-review/swarm-20261010-2154/audio-contract-freeze/revision4/fixtures.json`,
SHA256 `845b78d5269c4e5354defa68cba7e7881dcb265e4272159b365cfba7657ba834`.
The exact12 IDs are enumerated in the integration test; there is no F5. Tests
check every declared normalized sample bit, all remaining samples specified by
the patterns, each exposed RMS bit and each branch. Silence exposes no RMS field
in the approved API: its sole frozen all-zero case is checked through zero input,
all-positive-zero output, the Silence outcome and the independently verified
model RMS0. Empty has null RMS and leaves every raw output bit unchanged.

Earlier checker653 covered declared sample representations/RMS/positive-count
sentinel, not every JSON field. The count0 native sentinel fields and M2 nested
discriminator are manually audited here and checked by tests and the separate
oracle. M2's rounded-square RMS is `3f431a07`; widening before square gives
`3f431a08`. Constant32767 fixtures do not distinguish those paths. F7 checks all
alternating `38000000`/`b8000000` normalized samples. The copied F4 log-specialcase
and analytic dB fields are preserved as source-artifact content but are never
used to compute or validate a dB result.

The author's additional analytic controls are reproducible with
`sol-fast-review/audio-prelog-code/derive_oracles.py`; results are frozen in
`oracle-check.json`. This separate script uses integer/rational RNE square and
division, and Decimal sqrt at80/128digits rounded through f64 then f32. The full
i16 ramp has RMS `3f13cd3a`, versus `3f13cd1f` with f32 accumulation. Samples
`[-9979,-14244,21712]` have RMS `3efaf4a7`, versus `3efaf4a8` with f32-rounded mean.
These are analytic design controls, not additional vendor-runtime fixtures.
Sequential f64 accumulation order and absence of allocation/unsafe/FFI are also
checked by source inspection; no claim is made that short fixtures distinguish
every possible reassociation. The65536-sample ramp also exercises a valid count
above16000 and every signed host i16 value.

Capacity error preflight, unchanged error/empty buffers and unchanged success
suffix are independent interface policies tested with raw signed-zero and
quiet/signaling-NaN payload bits. Sound references and exclusive output borrowing
supply the safe aliasing contract. The frozen corpus's arbitrary-pointer wording
is outside this safe contract and does not establish native UB, fault, corruption
or allocation outcomes. No dependencies, log substitute, unsafe, FFI, allocation
or arbitrary count cap are added to the module.
