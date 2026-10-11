# PE64 shader evidence extraction

Owner: root, GitHub pastawithpesto.
Scope: src/bin/pe_shader_extract.rs, tests/pe_shader_extract.rs, and this plan.

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
