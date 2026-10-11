# Bounded Rust mask v2 decoder

Owner: `pastawithpesto`.

Task: implement the reviewed `mask_v2` decoder in safe Rust. Keep this leaf independent of pipeline registration. The integrator owns `src/lib.rs`.

## Reserved paths

- `src/stitch_mask.rs`
- `tests/stitch_mask.rs`
- `tests/fixtures/stitching/masks/**`
- `docs/tasks/stitch-mask-rust.md`

## Source base

- Repository and worktree root: `/home/violence/Projects/dji-studio-omarchy/native`.
- Owned worktree: `/home/violence/Projects/dji-studio-omarchy/source-worktrees/luna-b-5-stitch-mask-20261011`.
- Branch: `luna-b-5/stitch-mask-rust-20261011`.
- HEAD and fetched `origin/main`: `91f1fd620a7a0aea74db49a03be240ee59681401`.
- Fetch check: `2026-10-11T22:18:46Z`. Fetched main is an ancestor. The owned worktree started clean.
- The separate main worktree contains root-owned edits to `AGENTS.md` and `AUTHORS.md`. This task will preserve them.

## Evidence and scope

The independent review approved the exact Sol-2 contract hash `844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f`. The review hash is `2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6`. It approves `mask_v2` only within the named mask scope.

The reference is DJI Studio build `1.0.0.30839`. `VinceEditor.dll` SHA-256 is `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`. Original decoder locations are `0x180115740`, `0x180115752`, `0x1801157d7`, `0x180115985`, and `0x180116100..0x180116340`. The run loop reads count at `0x180116251`, checks zero at `0x180116257/0x18011625c`, reads value at `0x180116271`, fills at `0x18011628f`, and advances at `0x18011629c`.

The reviewed valid-resource oracle is `001-mask-byte-audit.json`. Independent malformed-input policy is in `003-independent-mask-policy-oracles.json`. The original valid mask inputs and expanded SHA-256 values are pinned here:

| Resource-relative path | Input SHA-256 | Input bytes | Dimensions | Expanded bytes | Expanded SHA-256 |
| --- | --- | ---: | ---: | ---: | --- |
| `102/mask_fisheye_master.bin` | `424ce1a41c7f6527825907470a2d20bf7d07fa3d18bd9f0ea84d069e4ecd577d` | 18779 | 1920 × 1920 | 3686400 | `4aefee1d6cc10a9574d827c9102704d21bcdbd9a45eb0edaed385624b7644703` |
| `102/mask_fisheye_slave.bin` | `1af0ddd3ac480424cbcaf2c01ecde282abfdd1f077cff8ecb1705b272f1f8b0b` | 18699 | 1920 × 1920 | 3686400 | `72ac29ba357777efff29f093e55b4267f0ac9510d69aa77f028d2a5588534a1b` |
| `530/dynamic_mask_fisheye_master.bin` | `22e4ae20a6dff318239a434693ac54e995ef981dbbf66cd373d0885e0651c6de` | 38544 | 3840 × 3840 | 14745600 | `88fd09e2401887a97fde8e3a4d5ca12a29486bd272df8049c0dddbc507e57056` |
| `530/dynamic_mask_fisheye_slave.bin` | `ed35acb29f356c5d999f703f4b88dffb5a20ca327f67d953ad9e20fcebfe84a0` | 37179 | 3840 × 3840 | 14745600 | `da39971579f083ee8f3de52a0633d69d40e50c69dde903d6d0da5b21d669e1bc` |
| `530/mask_fisheye_master.bin` | `56607c8df07154162b5d64a873334d9c88ff192be0b05cf01dc2d371e0cc9cbb` | 38804 | 3840 × 3840 | 14745600 | `c311aa5e38311de515d1214226e6b06edbab909a03c8b90b35269cacb01d1cf1` |
| `530/mask_fisheye_slave.bin` | `d249152de8e52818134cc2b5b8a34fdc2c779e32925578ac80688c6bce4c75c7` | 37439 | 3840 × 3840 | 14745600 | `caaa7e4b2a9601a8bded0ee4da5dfd2041dee280e74fef17ca71581c723ce6be` |
| `above_water/mask_fisheye_master.bin` | `186a291dc1ae6edc23313f6031f249ad559e515b5def5246715e06e5c287fc32` | 403159 | 3840 × 3840 | 14745600 | `ea2e474b7bd93b27fd5afd2048241655664d6754cc48ea2e88152ddd1ba045cc` |
| `above_water/mask_fisheye_slave.bin` | `bab4e0f209cdbb9358b407aa0a7a4473bec09361d9f8037b9e8c3e4c896a29dd` | 391949 | 3840 × 3840 | 14745600 | `9a21f5c32ea2bc8cf0d542ce9d0cf7191d73c17c2b60cc07bb8ce881ed21eec3` |
| `default/mask_fisheye_master.bin` | `186a291dc1ae6edc23313f6031f249ad559e515b5def5246715e06e5c287fc32` | 403159 | 3840 × 3840 | 14745600 | `ea2e474b7bd93b27fd5afd2048241655664d6754cc48ea2e88152ddd1ba045cc` |
| `default/mask_fisheye_slave.bin` | `bab4e0f209cdbb9358b407aa0a7a4473bec09361d9f8037b9e8c3e4c896a29dd` | 391949 | 3840 × 3840 | 14745600 | `9a21f5c32ea2bc8cf0d542ce9d0cf7191d73c17c2b60cc07bb8ce881ed21eec3` |
| `lens_protector/mask_fisheye_master.bin` | `e00c81c170173204b4387b54e3a7a43694ba230fa262a9f20631b8e1851314df` | 190134 | 3840 × 3840 | 14745600 | `1d98d33f30bfef10138689d7c677d7f34ca8ae191698623ac9cdcaf80e330db9` |
| `lens_protector/mask_fisheye_slave.bin` | `4dc177a37c550a5f06013dee1b4eb342b44e2f3fc3ed212c11f2785edfecbcad` | 186114 | 3840 × 3840 | 14745600 | `615deee25beca7d8596b2ade8842c033f9d16a526d31210cfe476f8220d1233a` |
| `under_water/mask_fisheye_master.bin` | `cab0b4d84dfc3ec89030c828f4fcb05dc9a44688eaa2291fd1792f6bbb99c010` | 17839 | 1920 × 1920 | 3686400 | `1a4bbf7c87cca13bf94cfe2c86678978ba90c8cf2f1d4177b33cab336ec7e93b` |
| `under_water/mask_fisheye_slave.bin` | `4d7571270f537c51aca5fcb6443449716efd13f92486d69f9ed6c6107d442888` | 18069 | 1920 × 1920 | 3686400 | `bb7403d31084307116f6d10635017e2a0ea9017ca41ec7069b3457e0299c03e7` |

## Decoder contract

Accept exact `panomask` magic, little-endian signed version 2, positive signed 32-bit dimensions, positive signed run counts paired with one byte value, and a four-byte zero run terminator with no value byte. Accept all byte values and adjacent equal runs. Preserve decoded bytes in linear order.

Use checked dimension conversion and multiplication. Enforce a caller-supplied `max_decoded_bytes` limit before allocation. Preflight the complete run stream without allocating a run list. Require exact decoded extent at the zero terminator and EOF immediately after it. Use fallible exact reservation for the output vector. Return no partial output on error. Use safe Rust only.

Errors follow the contract's `MaskErrorKind`, precedence, and offsets. These checked failure and allocation rules are independent Rust policy. They do not emulate malformed vendor writes.

## Exclusions

Do not add version 0 or 1 support, raw fallback, file I/O, GL, FFI, unsafe code, or conversion from decoded bytes to seam indices or another buffer. Do not infer row orientation, lens meaning, texture identity, camera behavior, project compatibility, or Windows parity. Malformed vendor behavior remains unknown.

## Plan and completion checks

1. Keep the API bounded to `decode_mask_v2(input: &[u8], limits: MaskLimits) -> Result<DecodedMask, MaskError>`.
2. Add fixtures from the 14 pinned original mask resources. Verify each input hash before copying. Do not add original executables or DLLs.
3. Test every original expanded length and SHA-256, plus representative resource metadata.
4. Test malformed headers, every truncated field class, negative and overflowing runs, early terminator, missing terminator, trailing bytes, dimension and multiplication bounds, limit boundaries, and fallible-allocation behavior where a deterministic seam exists.
5. Keep tests independently runnable through a small Rust harness if `src/lib.rs` registration is pending. Do not edit the integrator's files.
6. Run formatting, focused tests, build, and Clippy as applicable. Record exact compiler, commands, outputs, source identities, fixture hashes, and limitations in this PR.
7. Push a draft PR. Obtain independent review of the exact candidate. Do not merge or claim feature parity.

The work is complete only for the bounded decoder implementation and its checks. Camera input and paired Windows output are unavailable. This task cannot establish full stitching parity.
