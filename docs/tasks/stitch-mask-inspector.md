# Read-only mask inspection tool

Build a standalone Rust tool that uses the exact PR12 mask decoder.
Dependency: bb17bf53e7e06981f0258ea987530e719d1f8b4f.
Preserve its author files and commits.
Own tools/stitch_mask_inspect.rs and tests/stitch_mask_inspect.rs only.
Do not change Cargo.toml, src/lib.rs, decoder files or original fixtures.

Reference: DJI Studio1.0.0.30839 VinceEditor.dll.
Original SHA256:9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42.
Mask decoder body:0x180116100.
Approved mask_v2 contract:844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f.
Independent contract review:2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6.

The command takes one file path and an optional maximum decoded byte count.
Emit dimensions, compressed byte count, decoded byte count and256 byte counts
as JSON only after successful decoding.
Keep path arguments native to the operating system.
Read input only. Never write or replace it.
Use a64MiB encoded-file limit and a16MiB default decoded limit.
Honor the supplied decoded limit. Report malformed input with decoder error offset.
The CLI, limits, JSON schema and exit codes are independent tool policy.
The histogram gives byte frequencies, not alpha, seam, row or camera semantics.

Compile directly with rustc to avoid changing binary discovery or Cargo.toml.
Test real CLI behavior, meaningful malformed cases and input preservation.
Check all14 original masks against compressed-run histogram oracles.
Run debug/release focused tests, formatting and Clippy.
Request independent review of the exact tool and dependency identities.
Keep the PR in draft. No merge or release is requested.

## Build and use

```sh
rustc --edition=2024 -O tools/stitch_mask_inspect.rs -o target/stitch-mask-inspect
target/stitch-mask-inspect FILE [MAX_DECODED_BYTES]
```

The command returns0 on success,2 for invalid arguments, and1 for input or
output errors. Invalid masks report the decoder error kind and byte offset.

## Validation

Rust/Cargo1.98.1 on x86_64 Linux.

- Debug CLI tests:6 passed,0 failed.
- Release CLI tests:6 passed,0 failed.
- All14 original input hashes and lengths match the fixture manifest.
- Every original byte histogram matches an independent weighted-run calculation.
- Original input bytes remain unchanged after inspection.
- Tool and test Clippy checks pass with warnings denied.
- Formatting and diff checks pass.

The executable reports1920 by1920,18,779 encoded bytes and3,686,400 decoded
bytes for102/mask_fisheye_master.bin. Byte0 occurs920,326 times.
Byte255 occurs2,766,074 times. This example states raw byte counts only.
The exact decoder source hash remains
0a94d272bfffc318998f990e161f8ae12f957acdd92a001771c6d8f093a5b734.
Independent tool and dependency code review remain pending.
