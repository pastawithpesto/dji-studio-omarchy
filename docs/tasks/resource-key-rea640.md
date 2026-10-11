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

## Approved scalar evidence

The independent contract review approved only these two calculations.
Contract SHA-256:
815f466606b6f5f35729ec9796254071d83160238015457b2e7c78955f7df943.
Review SHA-256:
dc54e2353152952b3ee6ce5ba87b90be7b647124294e49b5ed5fd37fed048f42.
The exact contract is copied into tests/fixtures/resource-key/CONTRACT.json.
The local research packet and independent review are preserved at
reconstruction/root-resource-sdk-rea640-20261011.

REA package and server both report6.4.0. Ghidra12.1.4 produced fresh dossiers:
- Bucket: ev_67f6a747e8f4d56db0ffc0545b63729f2ad6301a1b55d7f74a454c47ed571ab8.
- Hash: ev_ff6526a99187d2a1a7349815ba4bab559ad3b6a021d2e8e0c9f01c0ac444b9ed.

Both complete REA read_bytes captures match original PE file bytes.
The key length load is at0x1800033d3. The hash basis and loop are at
0x1800033e4..0x180003413. Each byte is zero-extended; multiplication wraps
modulo2^64. The supplied length includes any embedded NUL or high byte.

The original unsigned guard at0x180005d57 rejects requests above2^59.
The scalar instructions0x180005d65..0x180005d85 calculate
((requested-1 wrapping) OR1), highest set bit plus1, then SHL with a masked
six-bit count. The count/mask stores are at0x180005d9b..0x180005da6.
Requested0 therefore gives count1/mask0. Requested1 gives count2/mask1.
Other admitted requests round up to a power of two with minimum2.
The safe Rust API returns TooLarge instead of a C++ exception.
A successful layout calculation does not imply successful original allocation.

The old6.3 snapshot was rejected with a profile integrity mismatch. Its full
failed call and logs remain preserved. One changed-input ephemeral import ran
under the exclusive lock and closed after saving a new owned6.4 snapshot.
No client registration, previous snapshot or toolchain configuration changed.
The original trailing INT3 is separately read from file bytes because Ghidra's
terminal-call annotation excludes it. That annotation is not runtime proof.

## Rust leaf

resource_key_hash accepts a safe byte slice. bucket_layout accepts u64 and
returns a typed count/mask or TooLarge. The module contains no unsafe code,
allocation, text normalization, filesystem operations or MSVC string objects.
Library registration is intentionally left to its existing owner.
`cargo test --test resource_key` runs the leaf before registration.
The fixture file has12 independently checked hash vectors and25 bucket vectors.
Tests also check neighbors of each power of two through2^59.
No real Windows call or allocation-failure comparison has been made.

## Author checks

System Rust and Cargo1.98.1, x86_64 Arch Linux.
`cargo test --test resource_key`: 4 tests passed.
`cargo test --release --test resource_key`: 4 tests passed.
`/usr/bin/cargo-clippy clippy --test resource_key -- -D warnings`: passed.
`rustfmt --edition 2024 --check src/resource_key.rs tests/resource_key.rs`: passed.
`git diff --check`: passed.
These checks include all37 fixed oracles and174 power-of-two neighbor cases.
They verify this scalar translation, not original heap/container execution.
Independent exact-candidate code review remains required.
