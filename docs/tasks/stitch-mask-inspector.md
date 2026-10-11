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
