# WindowPositionDetector finite milestone

APPROVED for the bounded static evidence milestone in root instruction 1573.
This decision verifies author handoff 1537 after independent Sol approval 1553.
It does not grant implementation or establish platform behavior or Windows parity.

Owner: astra. Feature: original Main WindowPositionDetector.
The user requested GPT-6 Astra High with Standard/default mode.
The tool interface does not expose the runtime service tier.
No Fast or Ultrafast option was requested. No worker was spawned.

## Source and current base

The source is the original DJI Studio.exe, build 1.0.0.30839.
Its length is 58,288,312 bytes.
Its SHA-256 is `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
The verifier read and hashed the complete original file.

Repository: `https://github.com/pastawithpesto/dji-studio-omarchy.git`.
Worktree: `/home/violence/Projects/dji-studio-omarchy/native`.
Branch: `main`.
HEAD and freshly fetched remote main: `91f1fd620a7a0aea74db49a03be240ee59681401`.
The verification fetch completed at `2026-10-11T08:37:28.937064+00:00`.
Remote main equals HEAD and is an ancestor. The worktree is clean.
Open PR 2 and PR 3 claims were read. This review changes no source or PR.

The author base remains `d661a3cdca7ca254524fdef2a3dbd7e52e89a95c`.
Only AGENTS.md and docs/tasks/current-base-rule.md differ from current main.
The author packet and archived base remain unchanged.
Current Main.qml has SHA-256 `ca96f270f65ce8ebb5ffe0038e00ea6d39f46df62f57511dd2a4f363b62c477e` and 35,548 bytes.
Lines 53-54 declare the detector. Lines 80-82 call its two methods.
These are static source callsites. They do not prove runtime invocation.

## Exact packet verification

The verifier checked all 50 author payloads, 10 declared inputs, and 9 tool inputs.
It also checked all 11 independent reviewer payloads.
Every length and SHA-256 matched. Both directory file sets match their manifests.
Both detached seals match their message pins.
The actual Sol message 1553 has review status `approved`.
Its report and sealed summary approve only bounded static evidence.
Receipt 1575 is separate from this approval.

| Artifact | SHA-256 |
| --- | --- |
| Author REPORT.md | `e2656e1fdac02ba295a1e85626d66fe666c9777cdc200a78c6f26da85f85989c` |
| Author EVIDENCE-BUNDLE.json | `953bf76317660e72547f150147e31ddb01b734e9a49ce36cd0d3335afe504d7b` |
| Author window-position.snapshot.json | `10bf5d82a16c01b869c12ccaedf808f5d82f137ad636d173810c6f44f38ce90e` |
| Author FINAL-MANIFEST.json | `48796ca0cee451404eafc01fd38f285431a2efabcc4d473f960fc1c53da51fae` |
| Author SEAL.json | `f80e0ea7cfdb56deef5ae6cbd0853df5aac4cb57d9ee844c724aac251356a7d7` |
| Sol REVIEW.md | `792c09fcf1e99c544fb630b24a1aaeb240329c5129b5598fcb363c306076605d` |
| Sol MANIFEST.json | `8a20c88146ad611c669eab987b2a5aa8bf1905a429712ebf699132f3df6f3156` |
| Sol SEAL.json | `7a789399f825457978ebc33aa2ebe83bfac16f8fb6bf97b1ba853d7b2c51cdc5` |

The shared findings index has appended text since the Sol review.
Its first 33,108 bytes still match the archived input hash.
This expected index change does not change the reviewed source or packet.
VERIFICATION.json records both hashes. QUERY-NOTES.json records failed reads and their corrections.

## Saved evidence and complete ranges

All three receipts match their Evidence bundle records.
The snapshot contains the exact bundle and matching results.
The target hash, Ghidra 12.1.4 identity, operation, and parameters agree.
The profile digest is `aac3538bbb660abb1bfb4ea3c3b1fdde18bf4afebbae9239fc5a0664e23a14ff`.

| Method | Inclusive range | Bytes | Instructions | REA Evidence ID |
| --- | --- | --- | --- | --- |
| Predicate | 0x1413a6500..0x1413a6602 | 259 | 71 | ev_5879301436e1c4e5385d70352a9fec77324e97ed4653ea370838200c30721fcb |
| Reset | 0x1413a6910..0x1413a6a6c | 349 | 93 | ev_9abb96dbda22bae2d36d18d98dd0f27150229b3ad2af2923536b975a0204e81c |
| Selector | 0x1413a6360..0x1413a646d | 270 | 77 | ev_c2922ce3651d04029179e02400a334023fd89f48ee2d36fcc6ed232235b5a190 |

The verifier reused the sealed independent disassembly.
It compared each instruction byte with the original PE mapping.
All 241 instruction addresses agree with the dossiers.
The byte ranges have no gaps. All 277 author byte rows also match.
This check did not repeat a disassembly, live import, or full reverse engineering pass.

Reset has three contiguous pdata fragments with exclusive ends:

- 0x1413a6910..0x1413a694a, unwind RVA 0x33b74b8.
- 0x1413a694a..0x1413a6a65, unwind RVA 0x33b74c8.
- 0x1413a6a65..0x1413a6a6d, unwind RVA 0x33b74ec.

The last two records have CHAININFO flag 4.
Both chain to the first fragment and unwind RVA 0x33b74b8.
The verifier decoded these records directly from the original PE.
The complete reset body is therefore supported by the saved ranges and original bytes.
Fourteen named IAT joins, 28 indirect callsites, and nine relative joins also match.

## Static claims and limits

Each claim here uses the pinned EXE, the corresponding dossier above, and the original byte checks in VERIFICATION.json.
These are recovered static facts. They are not observed Windows behavior.

The predicate clears AL at 0x1413a6512 for a zero native window argument.
The metacall stores AL at 0x141463c6c.
The nonzero path skips null screen entries.
It calls QRect::contains at 0x1413a656f with its third argument zero.
If that result is false, it calls QRect::intersected at 0x1413a6588.
It compares four result DWORDs with the window rectangle.
Either successful branch selects true at 0x1413a65bc.
Exhaustion selects false at 0x1413a65c0.
This does not establish QML null conversion or invalid-rectangle semantics.

The selector sign-extends height and width before the product at 0x1413a63f7.
Its initial score is zero.
CMP/JLE at 0x1413a63fb..0x1413a63fe requires a strictly greater signed score.
A tie retains the earlier selected entry.
The empty-list branch at 0x1413a6398 bypasses primaryScreen and returns null.
A nonempty list with no selection calls primaryScreen at 0x1413a6414.
This result can also be null.
The numeric score is not a pointer or proved physical overlap area.
Runtime screen order and object validity remain unknown.

Reset returns without setPosition for a zero window or null selector result.
The other path calls QWindow::setPosition at 0x1413a6a4b.
EDX and R8D carry the two integer coordinates.
CDQ/SUB/SAR divides each 32-bit difference by two toward zero.
Signed conditional moves apply the lower bound and then the upper bound.
With stable getter values and no intermediate overflow, each coordinate is:

`min(screen_origin + screen_extent - window_extent, max(screen_origin, screen_origin + trunc((screen_extent - window_extent) / 2)))`

The expression is a qualified arithmetic interpretation.
The original repeated getter order and 32-bit operations remain authoritative.
An oversized window can produce a coordinate below the screen origin.
The packet does not prove that reset always places the entire window on a screen.

No target pseudocode contains halt_baddata.
The saved value-flow fields report no truncation and zero known omissions.
Those fields do not establish complete alias or call-side-effect recovery.
Undefined signatures, pointer score types, aggregate dimensions, apparent uninitialized locals, and hidden return-buffer types remain decompiler limits.
External-space labels are not Qt runtime addresses.

A future helper with supplied scores can isolate the static selection rule.
That injected interface is an independent design choice.
It is not a recovered vendor object layout or an implementation grant.

## Finite boundary

Qt rectangle semantics, DPI, coordinate units, frame decoration, effective movement, registration, and invocation remain unresolved in this approval.
No native test or Windows comparison was performed.
Implementation, UI parity, numeric or media output parity, file or project compatibility, and failure parity are not approved.
No full feature is complete from this decision.

Qt body packets 1559 and 1560 remain outside this approval.
Enum packet 1570 and helper correction 1569 remain outside it.
Root predicate packets 1557 and 1571 remain outside it.
Kimi packet 1558 also remains outside it.
Each needs its separate review gate.

Only the assigned new review directory and authorized bus records changed.
No application source, peer artifact, archived base, or vendor pin changed.
No vendor execution, native test, provider, import, service action, remote mutation, or spawn occurred.
This finite milestone is verified. The wider feature and parity gates remain open.
