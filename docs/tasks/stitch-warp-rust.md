# Rust warp coordinates

The user requests root to write application Rust.
Root owns src/stitch_warp.rs and tests/stitch_warp.rs.
The queued kernel author retains the other six scalar kernels.
The integration owner retains src/lib.rs.

Implement K-WARP from exact approved contract
844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f.
Independent review SHA256:
2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6.

Source: DJI Studio1.0.0.30839 stitch_with_sym.dll.
SHA256: 82c9e7f0c51b5a2d7c13597022326bdaee2dfd92824bd67790336029d55a67a8.
Shader: VA0x1802600a0, raw offset0x25f4a0.
Source SHA256: 86d9ba723f7c8b0b8fa9bd1e983c1e9b26bad1fabf9dafa229464142022c3d1b.
Host:0x180104440; step divisions0x180104553/0x1801045dd.

Use supplied UV, flow sample, flow scale, input size and output size.
Preserve ordinary f32 operation order.
Correct x by subtracting one once, then adding one once when required.
Preserve y coordinates and return inclusive validity flags.
Do not assume equal input and output sizes.
Use the approved finite/domain/dimension/result checks as independent Rust policy.
Define error precedence as dimensions, nonfinite inputs, UV domain, result checks.
Do not sample textures or infer camera, GPU or image output behavior.

Tests use the exact approved rational fixture and independently calculated
boundary cases. Run debug/release focused tests, formatting and Clippy.
Keep tests runnable without changing the integration owner's library exports.
Request independent review of the exact final commit.
Keep this PR in draft. No merge or release is authorized.

## Validation result

Rust1.98.1 and Cargo1.98.1.
- cargo test --locked --test stitch_warp:8 passed,0 failed.
- cargo test --locked --release --test stitch_warp:8 passed,0 failed.
- /usr/bin/cargo-clippy clippy --locked --test stitch_warp -- -D warnings:passed.
- rustfmt --edition2024 --check src/stitch_warp.rs tests/stitch_warp.rs:passed.
- git diff --check:passed.

The initial cargo clippy command selected an unconfigured rustup shim.
The installed system cargo-clippy completed without changing toolchain settings.
Library registration remains with the integration owner.
The tests load this module directly so they can run before registration.
