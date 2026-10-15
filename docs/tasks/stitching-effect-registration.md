# Trace the stitching effect registration

Owner: `pastawithpesto`.
Research worker: GPT-6 Astra, High.

PR 48 producer-03 stops at an indirect selected function.
Trace the initialization and registration of global `0x180a175c8` in the original
DJI Studio 1.0.0.30839 `VinceEditor.dll`.
Find the stored property key and function pointer.
Connect that registration to the `effect` lookup only when the bytes support it.
Do not infer a call edge from a matching name.

## File scope

- `docs/tasks/stitching-effect-registration.md`
- `docs/evidence/stitching-effect-registration/**`

## Source and prior evidence

- DJI Studio build: `1.0.0.30839`.
- File: `VinceEditor.dll`, 10,958,008 bytes.
- SHA-256: `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.
- Prior candidate: PR 48 at `78d8180533345ad021cf3f04dc05e3fd6294ae52`.
- Fresh source main: `d922d46337150db102cef675073cfa392ef92bbc`.

Preserve the prior packet and its original tool pins.
Use a separate current-upstream REA installation for new analysis.
Record the upstream commit, package version, running server and Ghidra version.
Reuse matching evidence before a new import.

## Plan and resource scope

1. Wait for a successful draft PR claim check.
2. Verify the original file identity and current upstream REA.
3. Use one owned Ghidra session with a maximum heap of 2 GiB.
4. Inspect references to global `0x180a175c8`.
5. Decompile the initializer and registration callers.
6. Check pseudocode against assembly and original bytes.
7. Trace the property lookup through `0x180228190` and `0x18026d520`.
8. Connect `0x180266b30` to `0x180198080` only if the selected pointer is proven.
9. Save the evidence, reproducible byte checks, failed probes and remaining limits.
10. Obtain independent Sol review and Astra verification before approval.

Do not run the vendor DLL. Do not change another worker's session or installation.
Stop each conclusion at the first unsupported runtime edge.

## Completion check

The record must identify the original bytes for each claimed instruction and
property key. It must distinguish registration from live function selection.
Checks must reproduce on the pinned source. Any unresolved selection or live
object relationship must remain explicit. This task does not implement or prove
full stitching, EIS, image geometry, field units or Windows/camera parity.

## Progress

Plan only. No new analysis or approval is claimed.
