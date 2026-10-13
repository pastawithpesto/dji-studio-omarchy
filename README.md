# Native Rust implementation

Early implementation, not full DJI Studio parity.

`cargo build` builds the `dji-reframe` CLI. `dji-reframe INPUT OUTPUT [YAW PITCH HFOV]` projects already stitched equirectangular video via installed FFmpeg v360. It refuses existing output files. Input and output paths remain OS-native, including valid non-UTF-8 Unix filenames; flags, encoder tags and angles require UTF-8 and report ordinary CLI errors otherwise. Raw dual-lens stitching, stabilization and a GUI remain unimplemented.

The FFmpeg backend, flat projection, 1920x1080 output, yaw/pitch/HFOV defaults of 0/0/90, angle limits, horizontal-to-vertical pinhole FOV relation, H.264/libx264 with CRF 20, yuv420p, optional AAC audio and faststart are independent prototype design choices. They are not recovered DJI settings or evidence of vendor parity. Astra's review (`astra-review/communication-code-review/REVIEW.md`, R4) leaves projection orientation, rendered pixels, codec quality and hardware selection unverified. The prior historical synthetic-export claim had no linked fixture, command or FFmpeg identity and is not treated as validation evidence.

The timeline library implements positive constant-speed mapping with nonzero trim/timeline offsets and rational frame alignment from `astra-review/REPORT.md`. Signed halfway rounding and fractional-frame boundary tests pass. Curve interpolation and caller policy for reverse/zero speed remain unresolved. `align_duration_us` deliberately returns `Err(InvalidFrameRate)` for nonpositive FPS and accepts i64 FPS inputs; these are independent API policies. The pinned Windows build 1.0.0.30839 `nle_core.dll` (SHA-256 `3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1`) uses signed 32-bit FPS values and returns zero through JLE branches at `0x1800f82d4`/`0x1800f82dd` to `0x1800f831a`. Source: `astra-review/nle-duration-alignment-assembly.json`, REA `ev_6dbb2d987fe9a7fff6f6e6aeef72db3ac5b69e4b2ac1fc0b58e7f5fe1e1f60d5`. Checked wider arithmetic rejects overflow; equivalence is limited to ordinary positive representable rates and nonoverflowing vendor arithmetic. No real-camera behavioral equivalence has been validated.

`cargo test` runs the time-domain boundary checks and Unix CLI integration regressions. The CLI tests inspect a real non-UTF-8 pathname and use an isolated mock FFmpeg to verify exact input/output argument bytes and existing command defaults. These synthetic pathname/command checks validate native CLI handling only; they do not decode/export media or establish Windows, projection or codec parity.

`dji-reframe --metadata INPUT` experimentally inspects an unchanged local regular
file with `/usr/bin/ffprobe`, using its `-data_dump_format base64` capability.
It reports the exact format encoder, first up to two detected djmd/xtmd tracks,
stream index/ID/tag/timebase, packet PTS/DTS/source position and decode status.
The library `metadata::demux::inspect_direct` retains complete original packet
bytes with successful or failed descriptor decoding. It supports the exact
oqb101/wab530 registry dispatch; other encoders remain explicit outcomes. It
performs no timestamp/axis conversion or cross-track synchronization. Additional
matching tracks are reported as excess; camd-only nested import is unsupported.
`--inspect` remains a top-level nested-container extent scanner; `--encoder`
performs exact registry lookup.

The probe transport, checked limits and error policies are native design under
`sol-review/resumed-demux-20261010/CONTRACT.md` (Astra contract98), using recovered
VinceEditor.dll1.0.0.30839 loader0x18034c3d0 and whole-packet forwarding
0x18034cb36–0x18034cb42 (SHA2569450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42).
CLI limits are64MiB stdout,64KiB stderr,256streams,10000packets/track,
16MiB/packet,64MiB total packet bytes and30seconds/probe; callers may supply
different limits. The library bounds both subprocess pipes before JSON parsing,
reaps its direct child on failure, preserves OS path bytes, and detects ordinary
source changes between probes. The identity checks are not an immutable snapshot
and wire/output limits are not an exact decoded-memory maximum.

The demux tests require installed FFprobe with base64 support and Python3. Twelve
independent synthetic BMFF carriers are pinned in `tests/fixtures/demux/`, with
matching one-track encoder/schema cases, selection and exact signed timing
oracles. Mock probes cover malformed transport, resource limits, child cleanup
and source changes. Mixed-schema carriers test transport only, since a shared
global encoder still dispatches all packets. Camera files, the Windows reference,
nested formats and DJI assembled conversion remain unverified.

## Agent contributors

Agents contributed code, research, and independent review to this project.
The table shows the verified roles in [AUTHORS.md](AUTHORS.md).

| Agent | Contribution |
| --- | --- |
| Codex / GPT-6.1 Sol | Rust code, tools, research corrections, and separate independent reviews |
| GPT-6 Luna | Resource recovery, packaging, and static research |
| GPT-6 Astra | Independent review and milestone verification |
| GLM-5.3-Flash | Resource SDK analysis and correction reports |
| Kimi K3, through NVIDIA | ThumbnailProvider static research |
| Qwen3.8-Flash, through Alibaba | Asset inventory and embedded URL survey |

Credit identifies the contributor. Each contribution keeps its own review status.
Recovered DJI content keeps its original authorship.
See [agent credit instructions](docs/AGENT-CREDITS.md) for GitHub commit credits.
