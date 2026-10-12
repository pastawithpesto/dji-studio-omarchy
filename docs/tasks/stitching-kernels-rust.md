# Approved stitching scalar kernels in Rust

## Owner and scope

Owner: `pastawithpesto`. Rust author: GPT-6 Luna High, routed as `sol-3`.

Implement only the six leaves approved in Sol-2 contract SHA-256
`844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f` and
Sol-Ghidra review SHA-256
`2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6`:

- `K-LINEAR`
- `K-BAND-WEIGHTS`
- `K-BUFFER-COORD`
- `K-BAND-COLOR`
- `K-GAUSSIAN`
- `K-AI-DIM`

The exact source scope is `src/stitching.rs`, `src/stitching/**`,
`tests/stitching.rs`, `tests/fixtures/stitching/pipeline/**`, and this task plan.
Root owns K-WARP in a separate module and PR. This change does not implement or
copy K-WARP. It does not edit `src/lib.rs`, `Cargo.toml`, dependencies, UI code,
or peer mask files.

## Evidence

Reference build: DJI Studio `1.0.0.30839`.

Original `stitch_with_sym.dll` SHA-256:
`82c9e7f0c51b5a2d7c13597022326bdaee2dfd92824bd67790336029d55a67a8`.
Original shader spans and source SHA-256 values are in the reviewed contract's
`evidence.SHADERS.original_shader_spans` and
`sol-ghidra-review/stitching-rust-swarm-20261011-2107/001-shader-byte-checks.json`.
The source slots include `band-blend.frag` at `0x180260630`,
`band-blend-v2.frag` at `0x180261410`, `band-blend-buf.frag` at `0x180261ef0`,
`band-blend-buf-v2.frag` at `0x1802634d0`, and
`novel-view-blend-v2.frag` at `0x18025dbf0`. The review confirms all seven
shader blobs, source slots, raw offsets, NUL terminators, and hashes.

The AI dimension predicate is in the same original DLL at
`0x1801c1b90..0x1801c1d0b`. The signed positivity checks are at
`0x1801c1ba1` and `0x1801c1bac`. Equality checks are at `0x1801c1bb4` and
`0x1801c1bb9`. The zero success return is at `0x1801c1bbe` (`33 c0`, `xor eax,eax`).
The failure return is at `0x1801c1cfe` (`b8 56 d4 f6 ff`,
`mov eax,0xfff6d456`).
Sol-Ghidra reviewed the exact original span. Its saved RAE ID is
`ev_638d086419486be852e9ae3f632306dba34b143570af609729d2959e960c1439` for
shader host context and `ev_c37cbab125f8fab3a48e1f2078cce9c694e44be81e49d3e251dea2075f534433`
for the related host path. No live RAE import or vendor execution is claimed.

## Implementation plan

1. Add pure scalar functions that match the six contract equations and public
   signatures. Keep sample inputs supplied by callers.
2. Keep the checked Rust error policy distinct from recovered shader behavior.
   Require finite inputs and results, valid dimensions, and the declared domains.
   Preserve source operation order. Do not use fused multiply-add.
3. Preserve the Gaussian's 25 coefficients and row-major accumulation order.
   Do not normalize the coefficients or clamp color outputs.
4. Implement the AI predicate exactly. Check nonpositive input dimensions before
   the size mismatch. Do not add a dimension maximum to that predicate.
5. Add focused tests and independent literal fixtures. Derive expected values
   from the original shader equations and binary-rational math. Do not call the
   Rust implementation to generate expected values.
6. Run focused debug and release tests, formatting, Clippy with warnings denied,
   and a diff-scope check. Record compiler identity, commands, results, tolerances,
   source identities, and limitations in the PR and task packet.

## Completion check

Exact binary-rational fixtures must match with zero tolerance. The Gaussian
fixtures must match the reviewed source-ordered scalar oracle or its stated
fixture-specific bound. Test interval boundaries and collapsed intervals,
negative mask ranges, band limits, all four color channels, index clamping,
nonfinite inputs, overflow results, dimension equality and mismatch, and error
precedence. Tests must confirm no partial output on error. Independent review
must inspect the exact candidate commit.

## Source and limits

The initial source base is repository
`https://github.com/pastawithpesto/dji-studio-omarchy.git`, worktree
`/home/violence/Projects/dji-studio-omarchy/source-worktrees/sol-3-stitch-kernels-20261011`,
branch `work/stitching-kernels-rust-sol3-20261011`, and base commit
`91f1fd620a7a0aea74db49a03be240ee59681401`. A fresh `origin/main` fetch and
ancestry check are recorded in the PR and comms before source edits.

This scope implements scalar math only. It does not establish texture sampling,
seam-mask construction, mask-byte conversion, camera calibration, lens defaults,
flow dimensions, shader runtime behavior, GPU equality, original-camera output,
Windows parity, project compatibility, or vendor malformed-input behavior.
No merge, release, or feature-completion claim is part of this task.

## Implementation status

The six functions and their focused integration harness are implemented.
Nine focused tests pass in debug and release builds. The fixture pins exact
binary32 oracle bits for the reviewed linear, band, buffer, color, and Gaussian
cases. The tests also cover branch edges, the low-band cap, band-step limits,
dimension errors, invalid domains, nonfinite inputs, and nonfinite results.

Direct `rustfmt --edition 2024 --check` and `git diff --check` pass. The installed
Clippy driver passes on the stitching test target with warnings denied. The
standard `cargo clippy` entry point cannot select a toolchain in this shell.
The test-target-only Clippy invocation and initial toolchain errors are recorded
in the owned continuation packet.

## Additive D1 correction

The original author report `001-code-candidate/REPORT.md` remains frozen.
Its lines 44-45 incorrectly classify the success address as an error return.
The corrected classification above is supported by the original DLL bytes.
The original report SHA-256 is
`d14fb73a7c10cb5966209596e48def736d3b082025394c3b6ea963bb7b696562`.
This correction changes documentation only. The scalar source, tests and fixture
remain byte-identical to candidate `6e4db183bdd2b19980a92f8ea79adc8b6cb6608e`.
Independent review of the corrected candidate remains required.
