# FpsDetect local implementation

Owner: sol-1, GPT-6.1 Sol High. Root instruction 4065 reserves this local task.
The user requests local work. Do not open a PR, push, merge, or release.

Source base: `7a5d360342267cce0d05670a413c893407ec8d04`.
Branch: `local/gui-fpsdetect-20261013`.
Worktree: `/home/violence/Work/dji-gui-three-sol-20261013/fpsdetect`.
The source check at `2026-10-13T04:12:34Z` fetched main and read open claims.
Main is an ancestor. The initial worktree is clean. No claim overlaps this scope.

## Scope and plan

Own `gui/rust/fpsdetect/**`, this document, and `docs/evidence/gui-fpsdetect/**`.
Root owns host integration. Preserve original QML, resources, and peer files.
Keep raw and private evidence in the assigned external research directory.

1. Read current instructions and matching saved evidence.
2. Verify the original registration, constructor, getter, callbacks, and units.
3. Implement supported behavior in Rust. Preserve QML URI and type `FpsDetect`.
4. Check arithmetic against original instructions. Check the QML contract.
5. Commit locally and request independent review of the exact candidate.

## Original reference

DJI Studio `1.0.0.30839`, `DJI Studio.exe`, SHA-256
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.

Saved packets pin ordinary TypeRegistration, URI and type `FpsDetect`, version
`1.0`, factory `0x140093a68`, and static metaobject `0x142fdc800`.
The metadata declares read-only `int fps`, `fpsChanged(int fps)`, and
`renderTime(double time)`. The saved declaration reports alone do not prove behavior.
Only two import lines occur in the saved 410-source QML scan. No direct object
construction or member use occurs there.

## Behavior and implementation

Constructor `0x141393500`, metacall `0x141463910`, accessor branch
`0x1414639b8`, signal thunks `0x14005fce0` and `0x14001a89d`, and callback
targets `0x1413941a0` and `0x1413942f0` are now audited from pinned original bytes.
Root grant `4082` permits bounded offline inspection and serial Qt checks.
Independent Sol High static review passed in bus `4096`.
See [the contract](../evidence/gui-fpsdetect/CONTRACT.md).

The core crate implements the original counter, mean, integer threshold, and
signal order. The Qt subcrate binds QQuickItem, QTimer, QElapsedTimer, and native
window render signals. It exports the original read-only property and signals.
Rust protects frame data with a mutex as an explicit safety choice. Native
connection kinds and repeated window connections retain the original contract.

The final application and fixture candidate is
`c6d699faef0b09e88bbacfc1308b9d4170e2146b`. Attribution-only main
`d922d46337150db102cef675073cfa392ef92bbc` is merged at
`2bd65458ddc61d0acd143a631fe0f1eb2aef102b`. No GUI or application source changed
in that upstream update.

The original namespace/class lookup and mutable signal callback hazards required
root's reviewed Rust-only CXX-Qt generator derivative. The final module uses its
shared callback option for all six bindings, clones frame/lifetime state before
user handlers, reloads fields in original order, and stops owner access after
destruction. GUI-thread assertions bound owner access. No frame or Rust owner
borrow survives a user handler.

Five focused Rust test groups pass. Final native runs 13 and 14 pass registration,
original signal/property metadata, real frame/timer behavior, nested callback
reloads, deferred destruction, and active Rust-callback destruction. Final run 14
also asserts the declared modern QML.Element class-info artifact. Earlier
failures remain preserved, including the unsupported synchronous deletion during
an active JavaScript handler. Exact commands, log hashes, compiler identity, and
limitations are in [the check record](../evidence/gui-fpsdetect/CHECKS.md) and
[the command record](../evidence/gui-fpsdetect/COMMANDS.md).

Independent source review of the final native source and generated immutable
handlers found no blocking defect. The sealed documentation/evidence packet is
submitted separately for final peer acceptance. No fresh vendor import or vendor
execution ran. All work remains local; root owns host integration.

Static proof, Rust checks, native registration, graphics output, and Windows
behavior are separate results. Full GUI and Windows parity remain incomplete.
