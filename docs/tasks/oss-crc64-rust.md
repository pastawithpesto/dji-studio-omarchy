# Original OSS CRC64 Rust translation

Owner: @pastawithpesto.

Implement the original `AlibabaCloud::OSS::ComputeCRC64` and `AlibabaCloud::OSS::CombineCRC64` in safe Rust. Use their exact original names. Record any required Rust identifier adaptation. Do not change the original UI or strings.

Source: DJI Studio distribution 1.0.0.30839, `alibabacloud-oss-cpp-sdk.dll`, 3,130,552 bytes, SHA-256 `083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1`.

Original exports start at RVA `0xc9a0` and `0x55c4`. Follow all jump stages to the actual bodies. The earlier benchmark verified only 100 jump wrappers. It does not establish these functions.

Own only `src/oss_crc64.rs`, `tests/oss_crc64.rs`, `tests/fixtures/oss-crc64/**`, `docs/tasks/oss-crc64-rust.md`, and `docs/evidence/oss-crc64/**`. Existing owners retain `src/lib.rs`, Cargo files and unrelated modules. Use direct test-module inclusion until the integration owner registers the approved module.

Plan:

1. Reuse matching evidence where supported. Use the latest owned REA upstream and Ghidra. Pin real bodies, table initialization, helpers, exact original bytes and tool versions. Preserve all warnings and failures.
2. Recover polynomial, bit direction, seed and output complements, byte order, length semantics and combine behavior. Obtain independent contract review before Rust edits.
3. Build a bounded original DLL reference fixture under Wine. Call only the two named exports with safe input buffers. Record exact outputs and loader limits.
4. Implement pure Rust without vendor execution or new dependencies at application runtime. Label slice bounds and any independent errors. Do not claim C++ ABI or allocator equivalence.
5. Validate reference rows, incremental and combination identities, empty and boundary inputs, full-width seeds and combine lengths. Run focused tests in debug and release, formatting and lint checks.
6. Request independent exact code and evidence review. Keep failed probes and correction history. Publish the candidate in this draft PR after checks. Full SDK behavior and Windows application parity remain incomplete.

The coordinator selects model and runtime settings outside worker instructions. Work only from freshly checked main. Use addressed comms and read new PR claims before edits and pushes. Do not expand the declared scope without updating the claim.

## Implemented candidate

Author: GPT-6.1 Sol, xhigh, as requested by the task owner. The dedicated source
worktree remains `source-worktrees/root-oss-crc64-rust-20261012`, branch
`work/oss-crc64-rust-20261012`. Main `91f1fd620a7a0aea74db49a03be240ee59681401`
was freshly fetched and is an ancestor of the task-plan base `7b499137`.
All current open PR claims were read. The assigned paths do not overlap.
Automatic PR watchdog run `38194066022` and manual complete claim check
`38194229947` passed before implementation.

The actual arithmetic bodies are RVA `0x1b4bc0..0x1b4ce4` for Compute and
`0x1b4850..0x1b4975` for Combine. Fresh REA/Ghidra inspection and complete
original-byte checks cover the generator, initializer and matrix helpers too.
Independent static contract review SHA-256
`24c6336adf1698ecf12d26132c5449c20b72098cf0d03c97f0e6060c0fe54d0c` approves
the exact contract SHA-256
`5e0bf31515b7630513a05ba6ca9c28328863de6106d7c9fed51746ffb21958f5`.
See [evidence](../evidence/oss-crc64/README.md) for source and tool pins.

`src/oss_crc64.rs` implements the original `ComputeCRC64` and `CombineCRC64`
names. Compute uses a safe slice and immutable compile-time base table.
Combine uses unsigned 64-bit lengths and fixed stack GF(2) matrices. Empty
Compute input returns its incoming seed. Zero Combine length returns crc1 and
ignores crc2. Slices, table lifecycle and omission of a foreign ABI are explicit
independent Rust policies. No source declaration or header is invented.

`tests/oss_crc64.rs` directly includes the module and replays all 3,753 sealed
original-DLL results plus 24 valid joins. The exact fixture SHA-256 is
`f9215b491f62b2a4cefc945c6f8f30b155b12d90c76699c3a12ddbe4fb862624`.
Eight further tests independently check polynomial arithmetic, every byte and
seed bit, every length bit, incremental calls, combination and composition.
All input-data hashes and copied fixture file identities are checked separately.

Validation commands and exact results are in
[validation.json](../evidence/oss-crc64/validation.json). The bare `cargo clippy`
subcommand reached an unconfigured rustup shim. Invoking the installed
`/usr/bin/cargo-clippy` with explicit installed Cargo, rustc and Clippy driver
checks the complete focused test target without changing global toolchains.

The additive loader trace confirms that the original SDK, libcurl and libeay32
loaded as native PE modules, while MSVC/UCRT support used Wine builtins.
All 3,729 primary rows agree with the sealed primary observations; the 24 join
rows remain separate. Both trace receipts and their exact hashes are preserved
without changing the original fixture or its initial receipt. This is Wine
reference evidence, not native MSVC or Windows equivalence.

Exact-candidate code and final reference review are pending. Keep PR30 in draft.
The integration owner retains parent module registration. This candidate does
not claim whole-SDK completion, Windows or application parity, network methods,
foreign ABI, malformed pointers, arbitrary process initialization or failures,
UI, media, camera or project equivalence. No merge or release is authorized.
