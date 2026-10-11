# Resource SDK signed decimal append

Root owns src/status_decimal.rs, tests/status_decimal.rs and this plan.
Use REA6.4.0 with the matching SDK snapshot. Inspect the scalar decimal output
of resource_sdk.dll1.0.0.30839 function0x180012a00. Original SHA-256:
006190faece698a6fffc6da68eacff3a996f75b1d6e362515cf2fa21bd58587d.
Preserve previous packets. No other source scopes change.

Pin the sign extension, INT_MIN magnitude, decimal digits, append length and
lack of a written terminator. Obtain independent contract review, then write
an allocation-free Rust append helper with a caller buffer. Native bounds and
atomic error policies replace the original allocator/object ABI.
Use exact decimal oracles, prefix preservation and capacity boundaries.
Compile only the leaf for debug/release validation. Use scoped Clippy and fmt.
Request exact candidate review. Keep the PR in draft. Library integration,
original allocator behavior and Windows parity remain separate.

Fresh initial main/HEAD:91f1fd620a7a0aea74db49a03be240ee59681401.
Branch:work/root-status-decimal-rea640-20261011. Initial worktree clean.
