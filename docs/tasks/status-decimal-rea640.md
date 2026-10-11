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

## Evidence and checks

REA6.4.0/Ghidra12.1.4 dossier:
ev_a30c3d04b1eca139f67d1cfbe47c9d38c2ae54958e6e4c716abd9429c1688478.
The342-byte body and a512-byte mapped capture match original DLL bytes.
MOVSXD at0x180012a2d widens EDX before NEG at0x180012aca.
The reverse-digit loop0x180012ae0..0x180012b08 emits at least one digit.
Copy arguments and used-length update0x180012b1a..0x180012b2f append exact
ASCII bytes. This body writes no explicit terminator. External allocator,
copy runtime, object ABI and cookie handling remain outside the port.

Contract SHA-256:
3d82349188b35f2510a6f8dd4e990612b4f3681d0e45aa2cae30ea9ab021fe1d.
Independent contract review SHA-256:
9677376ad724972854c5582bc9f7796b896ee1f1f75f5735bc41b79a9dbcecef.
Local sealed packet:reconstruction/root-status-decimal-rea640-20261011.

The Rust helper takes a caller buffer, used length and i32 value. It uses an
11-byte stack scratch, preserves prefix/suffix, writes no terminator and leaves
output unchanged on InvalidLength or InsufficientCapacity. These error and
capacity policies are independent native design, not vendor failure parity.
Library registration remains outside this claim.

System rustc1.98.1 standalone debug and optimized tests each pass5/5.
Nine fixed decimal oracles, every capacity boundary, invalid-length precedence,
repeated appends and4096 deterministic full-width values pass. Standard Display
supplies the independent canonical-decimal oracle for the generated values.
`/usr/bin/clippy-driver --edition 2024 --test tests/status_decimal.rs -D warnings`
passes. Formatting and diff checks pass. Standalone checks avoid a full build.
Final exact-candidate code review remains required. No vendor runtime/parity claim.
