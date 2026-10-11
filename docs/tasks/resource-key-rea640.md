# Resource SDK scalar Rust translation

Owner: root, GitHub pastawithpesto.
Scope: src/resource_key.rs, tests/resource_key.rs,
tests/fixtures/resource-key/** and this task plan.

Use REA 6.4.0 with the existing Ghidra 12.1.4 resource_sdk snapshot.
Pin DJI Studio 1.0.0.30839 resource_sdk.dll, 134840 bytes, SHA-256
006190faece698a6fffc6da68eacff3a996f75b1d6e362515cf2fa21bd58587d.
Inspect the key hash loop in 0x1800033b0 and the bucket-count scalar part of
0x180005d30. Check the REA pseudocode against original machine instructions,
including byte extension, wrapping multiplication, BSR and x64 shift counts.
Preserve the original GLM packets and saved snapshot. No new persistent import.

Propose and independently review a bounded scalar contract before application
implementation. Translate only supported key-hash and count/mask calculations
into safe Rust. Native typed errors replace the original exception path.
Do not port allocators, node layout, mutation, file I/O or inferred resource states.
Library registration remains with its existing integration owner.

Tests must use independent byte/integer oracles and explicit boundary values.
Record exact source and evidence identities, functions, offsets, REA IDs,
check commands, results, failed probes and limitations. Run focused debug/release
checks, formatting and system Clippy. Obtain independent exact code review.
Keep this PR in draft. No merge, release, complete SDK or Windows parity claim.

Initial source: fresh origin/main91f1fd620a7a0aea74db49a03be240ee59681401.
Separate branch: work/root-resource-key-rea640-20261011.
Initial worktree is clean. Other contributor worktrees remain unchanged.
