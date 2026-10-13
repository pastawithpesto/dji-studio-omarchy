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

## Bounded result

The current-main audit passed all 22 focused stitching tests in debug and
release. Full stitching remains incomplete. The audit and its separate hash
review are in `docs/evidence/stitching-stereo-pair-producer/`.

The finite producer task is complete. The original EIS export has no raw body
bytes at its RVA. The caller writes the literal `0x780` to `[R15+0x24]` and
`[R15+0x28]`, then later reads those fields. The complete intervening helper has
no direct access to those two offsets. Indirect effects remain unknown.

The immutable author packet is in `producer-01/`. The separate static review
is in `producer-01-review/`. These are relative to this task's evidence path.
The review approves only those static facts. It does not assign units or field
meanings, approve Rust changes, or establish Windows parity.

Next useful task: trace the construction of the caller object in a new bounded
static scope. A complete EIS producer needs a separately pinned authentic
implementation source. The real camera and Windows export files are also
required for the image comparison. Keep this PR in draft pending its required
exact-candidate review and milestone verification.

## Solo continuation: producer-02

The user requested continuation without agents. Root will author one new packet
in `producer-02/` under the existing evidence claim. Preserve `producer-01/` and
its review. Trace the incoming object for function `0x18013cd10` through saved
evidence and original PE bytes. Check direct call sites, exported identities,
and constructor edges where the bytes support them. Record unresolved aliases
and indirect dispatch. Do not assign field meanings from names alone.

First update the owned REA cache runtime to the fetched upstream commit. Keep
the measured runtime and its benchmark results unchanged. Reuse saved evidence
before a new import. Pin any new offline checks separately from REA output.
Check source hashes, instruction bytes, function bounds, and the precise object
dataflow. An unresolved constructor is an acceptable finite research boundary.
No application change is part of this continuation. Independent review remains
pending; root will not approve this new author packet or start another agent.

The producer-02 author packet is complete. It joins the constructor store at
owner `+0x450` to the stereo-pair caller's member load. The base initializer
zeros one qword across child offsets `+0x24` and `+0x28`. Its byte verifier passes
for 6,532 captured bytes and 23 fixed anchors. Live identity and field meanings
remain unknown. The packet has no independent review.

## Solo continuation: producer-03

The user asked to continue. Preserve producer-02 and trace the returned pointer
from helper `0x180281760`. Use an additive `producer-03/` packet under the same
claim. Identify the getter's exact source member and one supported writer path.
Check its connection to the outer stereo-pair caller. Stop at the first unresolved
selection or external producer. Keep runtime behavior and field units unknown
unless separate evidence proves them. No agent or application change is needed.

The producer-03 author packet is complete. The eight-byte getter returns member
`+0x88`. A setup path reads the original `effect` property, calls a factory, and
passes the result to a writer for that member. The factory queries
`mlt_properties_get_data` on global `0x180a175c8` and tail-jumps through the result.
The byte verifier passes for 1,424 captured bytes, 13 fixed anchors, and six exact
imports. A changed expected anchor is rejected. The new packet also verifies
the producer-02 seal and all its files. Independent review remains pending.

Next bounded target: prove the initialization and registration stored through
global `0x180a175c8`, then bind the selected `effect` value to the actual function
pointer. Do not join a name match to the constructor without the stored pointer
and selected call edge. The caller's live instance and later mutations remain
unknown. Full stitching, EIS math, and Windows/camera comparison remain open.
