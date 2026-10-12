# WindowPositionDetector static method packet

The one granted REA import completed. Three function dossiers returned usable pseudocode, assembly, call edges, and Evidence. The driver exported the bundle and saved a new snapshot. It then closed its own session. Independent Sol review and Astra verification remain pending. No application code changed.

Owner: sol-ghidra. Root grant: 1505. Source: DJI Studio.exe 1.0.0.30839. Source length: 58,288,312 bytes. Source SHA-256: `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.

REA: 6.3.0. Provider: Ghidra 12.1.4. JDK: 21.0.12.1. Analysis profile digest: `aac3538bbb660abb1bfb4ea3c3b1fdde18bf4afebbae9239fc5a0664e23a14ff`. The driver used the existing compiled runtime. It used command-local tool paths. It did not install, update, or configure REA. `LAUNCH.json` records the exact command and environment.

## Actual receipts and validation

The first function call ran from 07:42:15.027 UTC to 08:02:14.132 UTC on 2026-10-11. The other two calls used the same completed Ghidra session. All three calls, the export, and the close returned without `isError`. The driver exited with code 0. The target application did not run.

| Function | Complete body, inclusive | Bytes | Artifact | REA Evidence ID |
| --- | --- | --- | --- | --- |
| isWindowCompletelyOnScreen | 0x1413a6500..0x1413a6602 | 259 | PREDICATE.json | ev_5879301436e1c4e5385d70352a9fec77324e97ed4653ea370838200c30721fcb |
| resetWindowToBestScreen | 0x1413a6910..0x1413a6a6c | 349 | RESET.json | ev_9abb96dbda22bae2d36d18d98dd0f27150229b3ad2af2923536b975a0204e81c |
| Reset screen selector | 0x1413a6360..0x1413a646d | 270 | SELECTOR.json | ev_c2922ce3651d04029179e02400a334023fd89f48ee2d36fcc6ed232235b5a190 |

The corrected metadata inventory supplies the method names. The original metacall and thunk bytes join those names to the actual bodies. The sealed diagnosis packet records that join. This new packet does not repeat registration metadata extraction.

The original byte audit covers 277 disassembler byte rows. The three REA assembly address sequences match all 71, 93, and 77 original instruction addresses, respectively. Their complete ranges match the original windows. The two later reset unwind records chain to the first entry. This corroborates the full reset body. `DOSSIER-VALIDATION.json`, `OFFLINE-BYTE-AUDIT.json`, and `RESET-UNWIND-CHAINS.json` record these checks.

The three pseudocode bodies contain no `halt_baddata` placeholder. The native value-flow records report no truncation and zero known omissions. They still preserve decompiler and memory-alias limits. The native API database signatures remain `undefined` signatures. They are not recovered C++ API contracts.

The compiled REA parsers validate the canonical Evidence bundle and snapshot. A pure offline cache lookup finds the same three Evidence IDs for the exact target, provider, profile, operation, and parameters. `CACHE-VALIDATION-RECEIPT.json` records the command and result. This lookup starts no provider. It does not test a future CLI environment.

## Recovered static facts

Each claim below uses the pinned source and the corresponding dossier in the table. The original byte and IAT joins corroborate the named boundaries. None is an observed Windows result.

**Predicate.** The zero QWindow argument branch clears AL at `0x1413a6512`. The metacall stores only that byte as the metadata bool result. The nonzero path obtains the screen list and the window geometry. It skips null screen entries. It obtains each screen geometry. It calls `QRect::contains` at `0x1413a656f` with the third argument zero. If that call returns false, it calls `QRect::intersected` at `0x1413a6588`. It then compares four returned DWORDs with the window rectangle. Either successful test selects the true return. Exhaustion selects false. The relevant exits are `0x1413a65bc`, `0x1413a65c0`, and `0x1413a65f2`. This proves the static return branches. It does not prove QML null conversion or invalid-rectangle behavior.

**Screen selector.** The helper at `0x1413a64c0` calls the original `QRect::intersected` import. The selector obtains the result height and width. It sign-extends both values and multiplies them at `0x1413a63f7`. The initial score is zero. The signed comparison at `0x1413a63fb..0x1413a63fe` replaces the selection only for a greater score. A tie keeps the earlier selection. A nonempty list with no selected screen calls `QGuiApplication::primaryScreen` at `0x1413a6414`. The empty-list branch at `0x1413a6398` bypasses that call and returns the initial null selection. Runtime screen order and effective screen objects remain unknown.

The selector pseudocode incorrectly represents the numeric score as a `QScreen*`. The original MOVSXD, IMUL, CMP, and JLE instructions control the signed numeric interpretation. Do not adopt the pointer type or the rewritten comparator as an API contract.

The pseudocode also displays uninitialized aggregate locals and incomplete Qt return-buffer arguments. The original LEA and register setup supply the buffers. The pseudocode array dimensions and hidden C++ argument types are not recovered layout facts. The raw call setup and import joins must control any later ABI contract.

**Reset.** The zero QWindow argument branches directly to the return at `0x1413a6913`. The other path obtains `QWindow::geometry` and calls the selector at `0x1413a693c`. A null selector result branches to the epilogue at `0x1413a6944`. A nonnull result supplies `QScreen::geometry`. The later sequence obtains window width and height. It computes centered integer positions and applies signed clamps. It calls `QWindow::setPosition` at `0x1413a6a4b` with EDX and R8D as its two coordinate arguments.

The centering sequence uses CDQ, SUB, and SAR at `0x1413a6989..0x1413a698c` and `0x1413a69b5..0x1413a69b8`. This implements truncation toward zero after the preceding 32-bit subtraction. The later additions and bounds also use 32-bit operations. If getter values stay constant and no intermediate operation overflows, each coordinate has this expression:

`min(screen_origin + screen_extent - window_extent, max(screen_origin, screen_origin + trunc((screen_extent - window_extent) / 2)))`

This expression is a qualified arithmetic interpretation. It is not a universal overflow or runtime contract. The original repeated getter calls and their order remain authoritative.

The actual PE IAT joins identify `QWindow::geometry`, `QScreen::geometry`, `QGuiApplication::screens`, `QGuiApplication::primaryScreen`, `QRect::contains`, `QRect::intersected`, `QRect::x`, `QRect::y`, the extent getters, and `QWindow::setPosition`. The sealed diagnosis retains exact IAT addresses and mangled names. REA external-space labels are analysis database identities. They are not Qt DLL runtime addresses.

## Current source and original Main

Actual source path: `/home/violence/Projects/dji-studio-omarchy/native`. Branch: `main`. Verified HEAD and remote main: `d661a3cdca7ca254524fdef2a3dbd7e52e89a95c`. The worktree was clean. `CURRENT-BASE-VERIFICATION.json` stores the exact commands and current input hashes. The four required entry documents and `native/AGENTS.md` were read. All open PR claims were read. PR 3 reserves the continuation record. No branch or peer worktree changed.

Current Main.qml has 35,548 bytes and SHA-256 `ca96f270f65ce8ebb5ffe0038e00ea6d39f46df62f57511dd2a4f363b62c477e`. It matches the historical resource input. Lines 53-54 construct the detector. Lines 77-83 call the predicate and then reset if the predicate is false. The guide-opening handler calls adjustWindow. These source calls explain why this surface is needed for original Main. They do not prove startup reachability, successful registration, or actual invocation.

## Remaining questions and stop boundary

Independent Sol review must check the byte provenance, metadata-to-body join, Qt import ABI, return-byte interpretation, selector rule, fallback distinction, and signed arithmetic. Astra must verify the bounded milestone separately. No implementation grant follows from this packet.

Qt rectangle normalization, invalid rectangles, edge inclusion, coordinate units, DPI scaling, frame decorations, screen order, primary-screen availability, and effective move behavior remain unresolved. The target bodies pass geometry values to imported Qt APIs. Their implementation and platform effects were not executed or recovered here.

The next validation needs a pinned Windows scenario. It must cover a window inside one screen, a window across two screens, a window outside all screens, tied intersection scores, mixed DPI, negative screen origins, and an oversized window. A null argument needs a separate ABI or reference test. A future static Qt query must first pin the exact Qt binary and resolve its export bodies offline. This task supplies no guessed Qt body address and no new import grant.

The owned driver, REA process, and Java process are absent at their exact recorded identities. The shared lock probe succeeds. `CLOSE.json`, `FINISH.json`, and `RELEASE-VERIFICATION.json` support release message 1532. Only the owned session closed. The new snapshot and bundle belong to sol-ghidra. Earlier snapshots remain unchanged.

The import log contains missing-PDB, decompiler, type descriptor, and data creation warnings. Live log snapshots preserve them. No requested call failed. No target body was accepted from a bad-data placeholder. Parser success, byte agreement, and static recovery do not establish native or Windows behavior. Full original Main, UI, and Windows parity remain incomplete. This task stops at the sealed review handoff.
