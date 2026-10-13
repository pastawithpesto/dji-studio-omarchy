# DJI Studio stitching completion audit

Audit time: 2026-10-12 19:43 UTC.

## Source identity

- Repository: `https://github.com/pastawithpesto/dji-studio-omarchy.git`
- Authoritative repository checkout: `/home/violence/Projects/dji-studio-omarchy/native`
- Local checkout: branch `main`, HEAD `91f1fd620a7a0aea74db49a03be240ee59681401`.
- Fresh `origin/main`: `13357262099643200bffa435bce7a14528cf8d14`, fetched at 2026-10-12 19:41:31 UTC. The local HEAD is an ancestor of fresh main. The local canonical checkout is dirty: modified `AGENTS.md`, `AUTHORS.md`, and `docs/RESEARCH.md`, with untracked `reconstruction/`, `source-worktrees/`, and `tools/pr_acceptance/__pycache__/`. I preserved all of them.
- Validation checkout: `/home/violence/Work/stitching-cache-verification-20261012/luna-audit/source`, detached at the fresh main SHA above, clean. Its Cargo output is confined to `luna-audit/target`.

The current stitching source hashes are `src/stitching.rs` `b75ad1133ff9618a22d82df6bdf53de899278108b936bc76fb987b3e226a7f3f`, `src/stitch_warp.rs` `48421fc098592ec4aaba466b2da9e45c8f07c5c9c7c65d65511db54d64ec12ed`, and `src/stitch_mask.rs` `0a94d272bfffc318998f990e161f8ae12f957acdd92a001771c6d8f093a5b734`. Test hashes are `tests/stitching.rs` `d995cd650867028320490a5d5ba1860b62e3c7f45b5feaff14f0df867b6e76c2`, `tests/stitch_warp.rs` `f8adefc56fcc37cb939be16396dab4e36b6810fdef974a8f5b71d2cfcdc764ce`, and `tests/stitch_mask.rs` `11e19bbb1f8a8e119532d24086004e8ceff0315e0f1bd95fc526e04230bbd45b`. Scalar fixture hash is `8be168fc3dfb97c574426e2b85572341b51f424d7946098cf07a0c6911903032`.

## Scope, status, and approvals

I read the project `AGENTS.md`, `coordination/REA-WORKFLOW.md`, current `native/AGENTS.md`, `native/CONTRIBUTING.md`, `native/docs/STATUS.md`, and `native/docs/RESEARCH.md`, plus the stitching task scopes and sealed review packet. The project rules require exact source review, separate milestone verification, and reproducible Windows/reference comparison before feature completion.

The three modules are registered as public Rust modules. The approved scope is bounded mask v2 decoding plus K-WARP and six supplied-input scalar leaves. The functions do not provide the camera pipeline, calibration, seam-mask conversion, texture sampling, shader/GPU execution, model/profile selection, or full frame stitching.

Source gates are now complete for the bounded modules. PR12 mask, PR13 warp, corrected PR15 scalar kernels, and PR16 module registration each have independent Sol review and Astra milestone records; the current main files retain the approved source/test bytes. PR15's earlier D1 source citation error was corrected additively and independently reapproved at `7d577df073daabaf715d86676371026cf3f69f1b`, then at integrated commit `113d7820705d0e99dabd6d8c248b430beb3df760`. The PR16 registration was reviewed and milestone verified at `43566390a4120278e38a0d339522884313c33a0d`.

Coordination PR10 remains open and draft. Its claim covers only `docs/tasks/stitching-rust-swarm.md`; its latest owner update says the corrected caller-record research passed Sol review and requests the next evidence task. That task plan does not represent completed end-to-end implementation.

## Tests run

On Arch Linux with system Rust/Cargo 1.98.1, I ran the existing mask, warp, and scalar tests from the owned current-main checkout. Both debug and release passed 22 tests total: mask 5, warp 8, scalar kernels 9. Commands used `RUSTC=/usr/bin/rustc`, `CARGO_TARGET_DIR=/home/violence/Work/stitching-cache-verification-20261012/luna-audit/target`, `/usr/bin/cargo test --locked --offline`, and the same command with `--release`. The first attempt through the Rustup shim failed because no default Rustup toolchain is configured; the system binaries succeeded. Complete logs are [debug](stitching-debug.log) and [release](stitching-release.log).

These tests establish the checked native contracts and fixture/oracle results for this source tree. They do not exercise a camera stream, GPU, model, or Windows output.

## Original media and reference comparison

The repository contains the original compressed mask fixtures, including 14 resources whose original bytes and independent expansions passed the saved review checks. It also contains a scalar oracle fixture. It contains no camera frame or paired output fixture.

Saved PR34 evidence pins the matched pair `CAM_20260928221414_0263_D.OSV` (SHA-256 `50c84afcee7e17acf97a98d418f8b36bdd59122d0a80c9d6baf884646b98a7db`) and `exported_360_pano_clip2.mp4` (SHA-256 `76cbe885f960b520406440b5a7df2e8ddf1580099a1ee8565bd0acc6139c61e9`). The user confirmed the export was made directly by DJI Studio for Windows with no later edits; export settings remain unknown. The saved comparison used FFmpeg directly, not the Rust CLI. At 0.4 seconds it reported SSIM All `0.536222`, visible seams, and different geometry. The score is a bounded visual comparison, not a calibrated quality measure.

Neither pinned media file is present under `/home/violence` or `/mnt` in this audit environment. I did not copy or modify media, rerun the image comparison, or import a DLL/open the shared REA session. Thus there is no Rust CLI versus Windows reference comparison, and no parity result.

## Completion verdict and next bounded task

DJI Studio stitching is **not complete**. The bounded decoder, scalar kernels, module registration, independent source reviews, and focused tests are implemented and verified. Full processing behavior and reference parity remain open. Project status also marks processing incomplete.

The smallest next evidence task already identified by the latest approved research packet is to inspect the direct producer of the `EisGetStereoPair` return record and resolve its field provenance against the pinned `VinceEditor.dll` build 1.0.0.30839. The approved caller correction proves that the caller copies that record and overwrites ten fields before update/feed; it does not establish the remaining field meanings, pointer ownership, callback behavior, or calibration semantics. Reuse matching saved evidence and original bytes. Request any unavailable artifact or grant through the project owner before analysis; do not import a duplicate DLL into a shared session.

Once the needed input producers are understood, a separate parity task should run the Rust CLI on the pinned raw clip and compare synchronized frames with the pinned Windows export. That media pair exists only in saved evidence from another machine, so the comparison must run where those exact files are available and reverify both hashes first.

No application source was changed. This audit and test output are under the requested `luna-audit/` directory only.
