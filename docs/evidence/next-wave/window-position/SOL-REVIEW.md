# WindowPositionDetector independent static review

APPROVED for the bounded static evidence in handoff 1537. No material packet correction is required. This approval covers source identity, saved dossier identity, complete method ranges, original instruction branches, and PE import joins. It does not approve a complete geometry adapter or application parity. Separate Astra verification remains required.

## Source and base

Feature: original Main WindowPositionDetector. Vendor build: DJI Studio 1.0.0.30839. The original EXE has 58,288,312 bytes. Its independently checked SHA-256 is `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.

Repository: `pastawithpesto/dji-studio-omarchy`. Source worktree: `/home/violence/Projects/dji-studio-omarchy/native`. Branch: `main`. HEAD and actual remote main: `91f1fd620a7a0aea74db49a03be240ee59681401`. Final check time: `2026-10-11T08:18:29.550173+00:00`. Main equals HEAD. Status is clean. The remote query used `git ls-remote`. It did not rely on a cached ref.

The author packet keeps base `d661a3cdca7ca254524fdef2a3dbd7e52e89a95c`. Only AGENTS.md and docs/tasks/current-base-rule.md changed between that base and current main. Vendor and saved evidence pins remain unchanged. Current Main.qml remains 35,548 bytes with SHA-256 `ca96f270f65ce8ebb5ffe0038e00ea6d39f46df62f57511dd2a4f363b62c477e`. Its lines 53-54 construct the detector. Lines 80-82 call its two methods. Guide handlers call adjustWindow at lines 89, 98, 104, 111, 118, 125, and 134. These are source callsites, not observed invocation.

## Identity and complete ranges

All 50 author payload hashes and lengths match. The complete directory matches its manifest and detached seal. All 10 declared input hashes match. The three saved receipts, bundle records, and snapshot results agree on source, provider, profile, operation, parameters, and result. The snapshot embeds the exact bundle. These checks confirm saved evidence identity. They do not repeat provider execution.

| Method | Inclusive range | Bytes and instructions | Evidence ID |
|---|---|---|---|
| Predicate | 0x1413a6500..0x1413a6602 | 259 bytes; 71 instructions | ev_5879301436e1c4e5385d70352a9fec77324e97ed4653ea370838200c30721fcb |
| Reset | 0x1413a6910..0x1413a6a6c | 349 bytes; 93 instructions | ev_9abb96dbda22bae2d36d18d98dd0f27150229b3ad2af2923536b975a0204e81c |
| Selector | 0x1413a6360..0x1413a646d | 270 bytes; 77 instructions | ev_c2922ce3651d04029179e02400a334023fd89f48ee2d36fcc6ed232235b5a190 |

Independent objdump decoding matches all 241 dossier instruction addresses. The instruction bytes cover each complete range without gaps. All 277 author byte rows match the original PE mappings. Reset has three pdata fragments. The later two unwind records have CHAININFO flag 4. Both chain to 0x1413a6910..0x1413a694a with unwind RVA 0x33b74b8. The final fragment ends at exclusive address 0x1413a6a6d. The dossier includes the full reset body.

Original metadata rows confirm bool isWindowCompletelyOnScreen(QWindow*) and void resetWindowToBestScreen(QWindow*). Original E8/E9 joins connect the metacall indices to both method bodies. At 0x141463c6c, the metacall stores only AL for the bool result. Nine relative call/thunk joins, 14 named IAT joins, and 28 indirect callsite joins pass.

## Static facts and interpretation limits

The predicate clears AL for a zero native window argument. For a nonzero argument, it skips null screen entries. It calls QRect::contains with argument zero at 0x1413a656f. If that result is false, it calls QRect::intersected at 0x1413a6588. It compares four returned DWORDs with the window rectangle. Either successful test selects true. Exhaustion selects false. No QML null conversion or invalid-rectangle rule follows from these branches.

The selector sign-extends intersection height and width before their 64-bit product. CMP/JLE at 0x1413a63fb..0x1413a63fe permits replacement only for a strictly greater signed score. An equal score keeps an existing selection. The initial score is zero. The empty-list branch at 0x1413a6398 returns null without primaryScreen. A nonempty list with no selection reaches primaryScreen at 0x1413a6414. The report correctly rejects the decompiler pointer type for this numeric score. The score is not proved to be physical overlap area.

Reset returns without a move call for a zero window or null selector result. A selected screen reaches QWindow::setPosition at 0x1413a6a4b. EDX and R8D carry the two coordinates. CDQ/SUB/SAR implements division by two toward zero after the original 32-bit subtraction. Signed conditional moves implement the reported bounds. With stable getter results and no overflow, each coordinate has the reported expression:

`min(screen_origin + screen_extent - window_extent, max(screen_origin, screen_origin + trunc((screen_extent - window_extent) / 2)))`

This is a qualified arithmetic expression. Repeated getters and 32-bit operations remain authoritative. An oversized window can produce a coordinate below the screen origin. Do not claim that reset always puts a window inside a screen.

No target pseudocode contains halt_baddata. Saved value-flow records report no truncation and zero known omission counts. Those fields do not prove complete alias or call-side-effect recovery. Undefined database signatures, aggregate array dimensions, apparent uninitialized locals, and hidden return-buffer types remain decompiler limits. External-space labels are not runtime Qt addresses. The report states these limits correctly.

## Next smallest supported contract

A future pure selection helper can accept an ordered list of optional screen entries and supplied signed scores. Start with no selection and score zero. Skip null entries. Replace only for a strictly greater score. Keep the first selected entry on a tie. Return null for an empty list. For a nonempty list without a selection, use the supplied primary-screen result. That result can also be null.

The score follows sign-extended 32-bit height times width in the original selector. Supplying scores through an injected interface is an independent design choice. It avoids a claim about unresolved Qt rectangle behavior or vendor object layout. Fixed-score fixtures can validate this small policy. This review gives no implementation grant. The complete adapter still needs pinned Qt body evidence and Windows scenarios for rectangle validity, edge rules, DPI, coordinate units, frame decoration, screen order, and effective movement. Runtime registration and invocation also remain unverified.

## Exact author pins and stop boundary

- REPORT.md: `e2656e1fdac02ba295a1e85626d66fe666c9777cdc200a78c6f26da85f85989c`.
- EVIDENCE-BUNDLE.json: `953bf76317660e72547f150147e31ddb01b734e9a49ce36cd0d3335afe504d7b`.
- window-position.snapshot.json: `10bf5d82a16c01b869c12ccaedf808f5d82f137ad636d173810c6f44f38ce90e`.
- FINAL-MANIFEST.json: `48796ca0cee451404eafc01fd38f285431a2efabcc4d473f960fc1c53da51fae`.
- SEAL.json: `f80e0ea7cfdb56deef5ae6cbd0853df5aac4cb57d9ee844c724aac251356a7d7`.

VERIFICATION.json and CONTRACT-CHECKS.json contain independent checks. INPUT-HASHES.json records the current instruction and source pins. CURRENT-CLAIMS.json records actual GET results for PRs 2 and 3. Their paths do not overlap this review output. An initial out-of-range QML read failed. CONTRACT-CHECKS.json records its correction. No source defect followed from that read failure.

I used original bytes and saved evidence only. I did not execute peer scripts or vendor code. I did not start a provider, import a binary, change app source, change peer evidence, change services, or publish remotely. High reasoning and Standard mode were requested. I did not request Fast mode. This finite static review is complete.
