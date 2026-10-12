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
