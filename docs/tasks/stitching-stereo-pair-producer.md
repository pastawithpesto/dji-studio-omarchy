# Stitching stereo-pair producer proof

Owner: pastawithpesto. Coordinator: root. Evidence author and independent reviewer
remain separate. This is a bounded static research task under stitching PR 10.
It does not change PR 34 or application code.

## Scope

- `docs/tasks/stitching-stereo-pair-producer.md`
- `docs/evidence/stitching-stereo-pair-producer/**`

## Existing evidence

The corrected local packet binds the VinceEditor caller to
`pano_selfcali_feed_stereo_pair`. The original source is DJI Studio 1.0.0.30839
`VinceEditor.dll`, SHA-256
`9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.
The caller copies the `EisGetStereoPair` return record and overwrites ten fields
in `[0x18013d424, 0x18013d479)` before update and feed.
Correction manifest SHA-256:
`c7743cbc0691959589b6ae2ec84042e88fbd8cca784ebc34bda4094a281a64b9`.
The separate corrected Sol review seal is
`215acf21c50b45a92ab66235165151fb4ea8e3d56b953d4d1fd47c30c3321cc1`.

## Next action

Reuse the saved evidence and original byte captures. Verify the exact import,
export, and original bytes for the direct `EisGetStereoPair` producer. If its body
is unresolved, record that boundary precisely and trace one caller-side producer
for the overwritten record fields instead. Start with the two dword values loaded
from `[R15+0x24]` and `[R15+0x28]` and the pointer values through RSI and RBX.
Do not infer units, camera geometry, pointer ownership, or callback meaning from
names or layout alone. Do not import a large DLL or execute vendor code.

## Completion check

Pin the current source, original hashes, exact address ranges, source bytes,
assembly, saved evidence identities, and limitations. Preserve earlier packets.
Produce an additive finite producer report and portable byte witnesses. Obtain an
independent exact-packet static review. Any Rust implementation needs a separate
approved contract and source claim. Windows image comparison remains a separate
gate. This task cannot establish complete stitching or full vendor parity.

## Cache benchmark

The two local cache modes are measured separately with three fixed small QML DLLs
and five alternating pairs per DLL. The benchmark has its own local evidence
scope. It does not establish stitching image correctness or a stitching speedup.
