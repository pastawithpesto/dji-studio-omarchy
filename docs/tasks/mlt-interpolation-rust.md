# Implement five approved MLT interpolation adapters

## Owner and scope

Owner: `pastawithpesto`.

This task implements only these five approved original names as pure Rust `f64` adapters:

- `mlt_circular_ease_in`
- `mlt_cublic_linear_ease_in_out`
- `mlt_discrete_interpolation`
- `mlt_linear_interpolation`
- `mlt_smooth_interpolation`

The exact typo `cublic` is part of the original export name and stays unchanged. The Rust `f64` signatures are independent adapters. They do not claim the original C or C++ prototypes. No dispatcher or other direct easing export is implemented.

Owned source paths:

- `src/mlt/interpolation.rs`
- `tests/mlt_interpolation.rs`
- `tests/fixtures/mlt/interpolation/**`
- `docs/tasks/mlt-interpolation-rust.md`

Do not edit `src/mlt.rs`, `src/lib.rs`, Cargo files, or another owner's files.

## Evidence

Source: DJI Studio 1.0.0.30839 `mltframework-win.dll`, SHA-256 `59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c`.

The exact combined approval is `reconstruction/root-mlt-complete-rea640-20261011/contract-review/009-dispatcher-clarification/REVIEW.json`, SHA-256 `06d1fdd6c0dcbfffd76ef0924def24f0c2aa29096b1ae7d5a07b60f37636fe3b`, read with the approved corrected packet 003, its root clarification, and prior review 008. The five pure `f64` adaptations are explicitly listed in the approved review.

Original reference pins:

- Initial reference manifest: `161dde5718d667e458f2f5b269627590b744e818d3c8e3d09e560b6cd0b41cf6`.
- Interpolation extension manifest: `aff5bd1110eafd1b1f89c6dadfa622df4623cea621f11bd60844956ab7766fec`.
- The extension has nine binary64 input/output rows for each of these five direct names. The original `mlt_circular_ease_in` numeric approval covers finite inputs where `1 - t*t` is nonnegative. Its one negative-radicand row remains a Wine observation, not a numeric contract case.
- The reference DLL ran under Wine 11.17. Native MSVC runtime dependencies were used in the later run, with Wine UCRT and Windows services. This does not establish Windows parity.

## Implementation constraints

Keep each operation in the approved binary64 order. Do not add a clamp, iteration cap, NaN policy, or new error behavior. Keep `FUN_18001a320` internal; it is a REA label, not an original export. Do not implement the signed selector dispatcher, even though its graph has a separate bounded approval.

## Completion check

Use the attached exact original Wine rows as fixtures. Compare `f64::to_bits()` for every applicable row in both debug and release test runs. This gives 44 numeric assertions: eight in-domain circular rows and nine rows for each of the other four adapters. Record the excluded circular negative-radicand row and why it is outside the approved numeric domain. Record the exact commands, results, source tuple, candidate commit, fixture hashes, and limits in the PR and handoff.

Request independent code review of the exact candidate commit. Keep the PR in draft until review. Do not claim whole-DLL, Windows, UI, GPU, camera, project, or processing parity.
