# Supported stitching module integration

Owner: pastawithpesto. Routing identity: luna-audit.

## Scope and plan

Own only `src/lib.rs` and `docs/tasks/stitching-integration-rust.md`.
Register `stitch_mask`, `stitch_warp`, and `stitching` from the exact author
candidates. Do not edit author modules, tests, fixtures, or dependencies.
Preserve author commits in a separate local combined validation branch.
Push only this registration branch. The draft depends on source PRs 12, 13,
and 15. Registration alone cannot build until those source prerequisites exist.

Wait for the current watchdog to accept this claim before registration.
Run combined Rust formatting, build, Clippy, and tests once.
Return source defects to the exact author. Request independent
sol-fast-transfer review and sol-milestone verification of the exact candidate.

## Exact source prerequisites

| PR | Commit | Module | Author |
| --- | --- | --- | --- |
| 12 | `bb17bf53e7e06981f0258ea987530e719d1f8b4f` | `stitch_mask` | GPT-6 Luna High, luna-b-5 |
| 13 | `70005cae6ae6a3de6f00a5180c100e2b5a561f0c` | `stitch_warp` | root |
| 15 | `6e4db183bdd2b19980a92f8ea79adc8b6cb6608e` | `stitching` | GPT-6 Luna High, sol-3 routing |

## Evidence and limits

DJI Studio reference build: `1.0.0.30839`.
Contract SHA-256: `844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f`.
Independent contract review SHA-256: `2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6`.
These workspace packets live under
`sol-calibration-review/stitching-rust-swarm-20261011-2107/sol-2` and
`sol-ghidra-review/stitching-rust-swarm-20261011-2107`.

Original `VinceEditor.dll` SHA-256:
`9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.
Mask decoder locations: `0x180115985` and `0x180116100..0x180116340`.
Original `stitch_with_sym.dll` SHA-256:
`82c9e7f0c51b5a2d7c13597022326bdaee2dfd92824bd67790336029d55a67a8`.
Warp shader slot: `0x180436da0`. Source: `0x1802600a0`.
AI dimension predicate: `0x1801c1b90..0x1801c1d0b`.
Other exact shader spans and supported equations remain in the author task plans.
Saved host Evidence IDs are
`ev_638d086419486be852e9ae3f632306dba34b143570af609729d2959e960c1439`
and `ev_c37cbab125f8fab3a48e1f2078cce9c694e44be81e49d3e251dea2075f534433`.
The AI dimension predicate has no saved Evidence ID.

Root code review2196 approves exact PR13 candidate. Its review SHA-256 is
`63d83e8b0cca55c2e3690830d5d94ce2e943d7433140fca58ba32c2fa2b1fbf8`.
PR12 and PR15 code reviews remain pending at reservation.

Supported scope is bounded v2 mask decoding and seven supplied-input scalar
contracts. Malformed-input, allocation, finite-input, and error policies are
independent native design. The 14 original mask fixtures and reviewed independent
scalar oracles provide the comparison inputs.

Profile selection, camera calibration, seam conversion, texture sampling,
GPU equality, original camera frames, and paired Windows outputs remain excluded.
UI behavior and project compatibility are not established by this task.
No merge, release, or vendor parity approval is requested.

## Source base and completion check

Repository: `https://github.com/pastawithpesto/dji-studio-omarchy.git`.
Owned worktree: `source-worktrees/luna-audit-stitch-integration-20261011`.
Branch: `work/luna-audit-stitch-integration-20261011`.
Initial HEAD and fresh main: `91f1fd620a7a0aea74db49a03be240ee59681401`.
Check time: `2026-10-11T22:57:48Z`. Main ancestry passes. Initial worktree is clean.
Root-owned canonical documentation changes remain preserved.

Complete this bounded integration only after exact combined checks, separate
independent code review, and milestone verification. Feature completion needs
reproducible original camera and Windows comparison and remains open.

## Registration candidate

Draft PR16 reserves the two exact owned paths. Current watchdog snapshot
`snapshot-20261011T230000388492Z-4d0a9114.json` includes PR16 and reports no errors or collisions.
Registration exports all three available supported modules. No author module,
test, fixture, or dependency changed. Combined validation and final review follow.

## Combined validation result

Local tested candidate: `882f3fe1146bdc9daa68f40388f164b23fc31f11`.
Local tested tree: `84a528c967fb9669f6fceb18ab6f2a15c0caa99d`.
Validation branch: `validation/luna-audit-stitching-20261011`.
Worktree: `source-worktrees/luna-audit-stitch-validation-20261011`.
Each exact author commit is an ancestor. All 25 author paths are byte-identical
to their author commit blobs. No author source, test, fixture, or plan was edited.

Checks on Arch Linux x86_64, Rust/Cargo 1.98.1:

- System Cargo fmt check over all targets: pass.
- `cargo build --locked`: pass.
- System Cargo Clippy over all targets, with warnings denied: pass.
- `cargo test --locked`: 206 passed, 0 failed, 0 ignored.
- `git diff --check`: pass.
- A separate public library API probe: pass. It exercises mask decoding and
  a declared native allocation error, warp, linear blend, band weights, buffer
  coordinates, band color, Gaussian accumulation, and AI dimensions.

The author suites still load their modules by path. The public probe links the
registered library. It uses reviewed rational and binary32 oracle values.
All 14 original mask resources pass the author input and expanded hash checks.
System binaries and an owned target directory avoid unconfigured Rustup shims.
No toolchain, dependency, camera, or vendor runtime was changed.

This result adds documentation after testing. The final candidate must preserve
the tested `src`, `tests`, and Cargo blobs. Final source hashes and exact candidate
identities are in the owned integration handoff packet and PR16.
Fresh main at this checkpoint: `91f1fd620a7a0aea74db49a03be240ee59681401`.
Check time: `2026-10-11T23:04:02.029053+00:00`.
Main ancestry passes. Both owned worktrees are clean before this result update.

Root exact code review2196 passed. PR12 and PR15 code review, final independent
sol-fast-transfer review, and sol-milestone verification remain pending.
No real allocator failure or 32-bit target was tested. Original camera and paired
Windows output remain unavailable. These tests establish bounded native behavior.
They do not establish UI, project, GPU, camera, or complete stitching equivalence.
