# PE64 shader evidence extraction

Owner: root, GitHub pastawithpesto.
Scope: src/bin/pe_shader_extract.rs, tests/pe_shader_extract.rs, Cargo.toml,
and this plan. Cargo.toml adds only the existing CLI as default-run. This
preserves the documented cargo run command when the new binary is discovered.

Build a Rust read-only evidence tool. Map an absolute pointer-table slot through
AMD64 PE32+ headers and file-backed sections. Read the stored source pointer,
map its target, and extract its exact NUL-terminated UTF-8 shader text.
Report original addresses, file offsets, extents and text as JSON.
Use bounded file and source sizes. Reject malformed, ambiguous, virtual-only,
truncated and unterminated inputs under explicit independent native policy.
Do not load or execute the original binary. Do not infer shader execution.

Reuse DJI Studio 1.0.0.30839 stitch_with_sym.dll, SHA-256
82c9e7f0c51b5a2d7c13597022326bdaee2dfd92824bd67790336029d55a67a8.
Existing original shader inventory is in Sol-2 contract 844661a8 and its
independent review 2c4d8f54. Validate warp-img-v2.frag at table VA
0x180436da0, stored target VA 0x1802600a0, raw offset 0x25f4a0,
1174 bytes before NUL, SHA-256
86d9ba723f7c8b0b8fa9bd1e983c1e9b26bad1fabf9dafa229464142022c3d1b.
Independently reread the original file, pointer bytes, mapped section and text.
Check the other recorded original shader entries as a broader extraction oracle.

Use synthetic independent PE fixtures for address mapping and failure behavior.
Run focused debug/release tests, formatting and Clippy. Record exact source and
original artifact identities. Request independent review of the final commit.
This utility supports evidence collection. It does not change application behavior
or establish Windows, camera, GPU, UI or processing parity. Keep the PR in draft.

Initial base: origin/main and HEAD 91f1fd620a7a0aea74db49a03be240ee59681401.
Worktree: source-worktrees/root-pe-shader-extractor-20261011.
Branch: work/root-pe-shader-extractor-20261011. Initial worktree is clean.

## Use

Run `cargo run --bin pe_shader_extract -- INPUT_PE 0xSLOT_VA`.
The slot VA is an absolute preferred-image address, not a file offset or RVA.
The result is JSON with the stored pointer, file offsets, text byte count,
terminator offset and exact source_text. Decimal slot addresses also work.
The tool accepts only AMD64 PE32+ regular files up to 256 MiB. It limits source
text to 1 MiB before NUL and never scans beyond its file-backed mapped region.
It rejects overlapping virtual regions and invalid UTF-8. These are native
evidence-tool policies, not behavior recovered from the vendor application.
On Unix it opens nonblocking to reject FIFOs without waiting for a writer.
Input filenames retain OS-native bytes. It does not compute source hashes;
hash the original file and extracted text independently when sealing evidence.
The bytes reflect one file read, not an immutable snapshot of a changing file.

Example for the pinned original DLL:

```sh
cargo run --bin pe_shader_extract -- /path/to/stitch_with_sym.dll 0x180436da0
```

The output source_text must match the exact 1174-byte warp shader pin above.
Independent original-byte audit and Rust comparison records are in the local
research packet reconstruction/root-pe-shader-extractor-20261011.

## Author validation

Rust and Cargo: 1.98.1, x86_64 Arch Linux.
`cargo test --test pe_shader_extract`: 10 passed.
`cargo test --release --test pe_shader_extract`: 10 passed.
`/usr/bin/cargo-clippy clippy --bin pe_shader_extract --test pe_shader_extract -- -D warnings`: passed.
`rustfmt --edition 2024 --check src/bin/pe_shader_extract.rs tests/pe_shader_extract.rs`: passed.
`git diff --check`: passed.
`cargo run -- --help`: passed and selected the existing dji-reframe CLI.

The normal cargo clippy command first failed because it selected a rustup shim
with no configured toolchain. No toolchain configuration was changed. Direct
system cargo-clippy completed the same scoped lint check successfully.

Debug and release binaries each recovered all seven original shader entries.
All pointer addresses, file offsets, text extents, exact bytes and independently
computed SHA-256 values match ORIGINAL-BYTE-AUDIT.json. The 14 comparisons are
in FINAL-RUST-ORIGINAL-COMPARISON.json in the local research packet.
These comparisons validate static extraction only. Independent code review
remains required. No merge, release or full feature completion is claimed.
