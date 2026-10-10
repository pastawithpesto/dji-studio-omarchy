# Native Rust implementation

Early implementation, not full DJI Studio parity.

`cargo build` builds the `dji-reframe` CLI. `dji-reframe INPUT OUTPUT [YAW PITCH HFOV]` projects already stitched equirectangular video to1920x1080H.264 via installed FFmpeg v360; optional audio is encoded AAC. It refuses existing output files. Raw dual-lens stitching, stabilization and a GUI remain unimplemented. Synthetic media export has been verified.

The timeline library implements positive constant-speed mapping with nonzero trim/timeline offsets and rational frame alignment from astra-review/REPORT.md. Signed halfway rounding and fractional-frame boundary tests pass. Curve interpolation and caller policy for reverse/zero speed remain unresolved. Checked arithmetic reports overflow; this intentionally avoids copying native overflow behavior. No real-camera behavioral equivalence has been validated.

`cargo test` runs the meaningful time-domain boundary checks.
