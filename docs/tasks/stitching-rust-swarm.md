# Stitching research and Rust implementation

The user requested a swarm for DJI stitching research and code on 2026-10-11.
The user specified Rust.

Base: 91f1fd620a7a0aea74db49a03be240ee59681401.
Reference: DJI Studio 1.0.0.30839.

Three Luna High analysts have separate scopes: classic warp and blend kernels,
calibration and texture input producers, and AI profile selection.
GPT-6.1 Sol High prepares a bounded Rust contract.
An independent Sol High reviewer checks the evidence and contract before code.
Luna High implements the supported mask decoder in Rust.
GPT-6.1 Sol High implements only supported stitching kernels in Rust.
A separate Sol High integrator owns library registration and combined validation.
An independent Sol High reviewer checks the exact final commit.
Astra High verifies the reviewed milestone.

Use Standard/default mode with Fast disabled.
Run no more than three model workers at once.
Keep separate worktrees and source file ownership.
Preserve prior evidence, failed queries, and peer work.
Read current PR claims and actual shared comms at each checkpoint.

The original mask decoder is at VinceEditor.dll 0x180116100.
Existing mask packets 895 and independent review 956 are inputs.
Provider packet 1017 needs the additive address correction in review 1051.
Do not treat that packet as fully approved.
Use the original binary hashes from docs/RESEARCH.md and the local evidence.

Decode original valid mask fixtures with exact expanded-byte comparisons.
Use checked sizes, bounded allocation, and explicit errors for malformed input.
Those checks are independent Rust policy, not recovered vendor error behavior.
Test processing equations only with independently supported contracts.
Do not invent lens parameters, seams, model keys, or GPU semantics.

The source reservation includes src/stitch_mask.rs, src/stitching.rs,
src/stitching/**, src/lib.rs, tests/stitch_mask.rs, tests/stitching.rs,
tests/fixtures/stitching/**, and this task plan.
Keep other source scopes unchanged.
Keep the PR in draft.
No merge or release is authorized by this task.
Full camera output and Windows parity remain separate reference gates.
