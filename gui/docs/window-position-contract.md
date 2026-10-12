# WindowPositionDetector Rust policy contract

The original type and module are WindowPositionDetector, version 1.0.
Original Main.qml imports the module and calls isWindowCompletelyOnScreen and
resetWindowToBestScreen. Rust crate and value names are internal identifier
adaptations. No original QML, resource, UI text or layout changes in this step.

## Verified source and evidence

DJI Studio build: 1.0.0.30839.

| Source | SHA-256 |
| --- | --- |
| DJI Studio.exe | e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4 |
| Qt6Core.dll | 7da66834f98bcf7b05e285fe6ea2c03951aef596876caa9e42897bfa7d6f623b |
| Qt6Gui.dll | 9ba43e3a6418f08078b0f756b08beef0ae29438368ccf760398f9921c279fc25 |
| Original Main.qml | ca96f270f65ce8ebb5ffe0038e00ea6d39f46df62f57511dd2a4f363b62c477e |

The local method report is
`sol-ghidra-review/next-wave/window-position-methods/REPORT.md`, SHA-256
e2656e1fdac02ba295a1e85626d66fe666c9777cdc200a78c6f26da85f85989c.
Its independent source approval is bus1553; separate verification is bus1580.
The inclusive predicate, selector and reset ranges are respectively
0x1413a6500..0x1413a6602, 0x1413a6360..0x1413a646d and
0x1413a6910..0x1413a6a6c.

The local QtCore report is
`luna-review/luna-a-1/reverse-wave-20261011/qt-rectangle-bodies/REPORT.md`,
SHA-256 3e88512a524b99cf4b3668cfdb93d5e945a3008849c1a40d33fc434536545fc5.
Source approval1579 and separate QtCore decision1599 qualify the exact rules.
Both report hashes were checked before this Rust implementation.
Existing immutable packets and historical validation remain unchanged.

## Integer policy

Rectangles have inclusive signed DWORD endpoints. Width and height wrap each
subtraction/addition to 32 bits. For an axis, let T = wrap32(near - 1).
If signed far >= T, bounds are [near, far]. Otherwise bounds are
[wrap32(far + 1), T]. This is not general endpoint sorting.

A rectangle is null only when both far endpoints equal their respective T.
A single zero extent is retained. Contains uses the original proper=false
comparison. Intersection permits shared endpoints and returns [0,0,-1,-1]
when the original null or separation branches fail.

The original complete-screen predicate accepts containment or exact equality
between the intersection endpoints and the original window endpoints. Preserve
its default-null equality success path. The policy function operates on values;
native null pointer handling and screen enumeration are not implemented here.

Intersection height and width are sign-extended after wrapped DWORD results.
Their signed 64-bit product supplies the score. Selection begins at zero and
requires a strictly greater score. Positive ties keep the first index. An empty
list gives no screen. A nonempty list without a positive candidate requires a
lazy primary-screen query. The Rust Selection value expresses that decision;
it does not query a native screen itself.

## Reset ordering

The getter sequence is exact:

```text
window.width, screen.width, screen.x,
window.height, screen.height, screen.y,
screen.x, screen.y,
window.width, screen.x, screen.width,
window.height, screen.y, screen.height
```

Each arithmetic operation wraps before signed comparisons. Halving truncates
toward zero. Preserve repeated getters and oversized-window results. The Rust
ResetGeometry trait is an independent safe adapter, not the original ABI.

## Validation and remaining limits

The 27 Rust tests use literal examples from approved endpoint and instruction
contracts, including the preserved earlier adapter validation cases. They do
not use the C++ implementation as a runtime oracle. Debug and optimized tests
pass, as do direct system rustfmt and Clippy checks with warnings denied.
Initial Cargo subcommand dispatch selected an unconfigured rustup shim; those
tool failures are preserved locally. Direct installed tools passed without
changing toolchain configuration.

No QObject registration, QWindow ownership, native movement, original Main
startup, UI interaction, media output or Windows parity follows from this
policy crate. The current C++ host and independent screen remain unfinished
migration work. Original UI resources must stay exact in later Rust/QML work.
Independent review of this exact Rust candidate is still required.
