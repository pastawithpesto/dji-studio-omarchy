# Synthetic direct-track carriers

These 12 small MP4 files are exact copies of independently authored Luna High
fixtures, not DJI camera samples. `manifest.json` pins every source path and
SHA256. Workspace source is
`luna-review/instance-a/resumed-demux-20261010/`; its `REPORT.md`,
`ffprobe-exact-contract/matrix.json` and `ffprobe-edge/` record commands and
independent byte/timing observations. Generator copies and hashes are retained
in `sol-review/resumed-demux-20261010/independent-generators/`.

The generator uses a one-frame FFmpeg video template and authored BMFF metadata
sample entries containing the existing descriptor-generated
`../metadata/oqb101-complete.pb` (241 bytes) and `wab530-complete.pb` (316 bytes).
The original mistaken all-OQB mixed fixtures remain in Luna's earlier directory;
the committed carriers use its corrected acceptance outputs. Acceptance is for
the installed `/usr/bin/ffprobe` n9.0.1, SHA256
`4493102ef9a9dee472ce68b540ba0fd3d2f714db0de930f299f681c72ec61832`.

Matching positive carriers are `one-djmd-oqb101.mp4` (global encoder DJI Osmo360)
and `one-xtmd-wab530.mp4` (Osmo 360 II). Both have stream index0, ID0x1,
timebase1/1000, PTS/DTS0, position749 and the full corresponding protobuf bytes.

Mixed carriers prove stream selection and transport only: every packet still
dispatches using the **single global encoder**. Their OQB/WAB payload mismatch
does not establish two semantic schemas in one camera file. Mixed indexes are
0/2 with video index1; the three-track carrier also has excess index3. The
two-track carrier has timebases1/1000 and1/90000. Edge carriers preserve PTS/DTS
-1 and144115188075868217 without floating-point conversion.

Remaining carriers cover unknown, empty and absent encoder, absent direct tags,
and camd-only explicit nested-unsupported handling. camd carries an authored
sample only; it proves no nested camera format. Truncated bytes and malformed
probe/packet data are created in owned test temporary directories.

Tests require the installed FFprobe and Python3 (mock process transport). These
fixtures establish native transport/schema behavior, not Windows/camera parity,
timestamp meaning, axes, assembly conversion or nested support.
