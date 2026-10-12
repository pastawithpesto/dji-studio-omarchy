# Bounded complete-resource code and prepared integration approval

APPROVED for bounded integration: original author commit `632efe2a3e63296f30a980606d424284d8876a3c` on base `9e021a401f94e5465f14885ae9b4b50fa1182583`, exactly carried by prepared PR1 commit `782541268cdc73acb5e76dbf22fa1683f686510e` on approved main `9053c4fbe1b33f6c148ee50ece16788373ecae88`. No material code, byte-preservation or integration blocker remains in this grant. Root may integrate this exact bounded resource increment. This review did not merge, fetch, publish or alter a branch and does not establish current remote state.

This is the additional Astra milestone gate requested by root1357 and the user, after independent Sol High approval1350. Sol's exact review SHA256 `c7d495d8dcb1dd8a2fdf1d9f62f556ea59d5256f96d897abf9f94c41334665a2`, manifest `020a9249265d9ac87f38d76328cbbf7fcc5c252f09af58e870fac597f7c1eaf4` and seal `3ea6918263ec3b87562f359436fa45ccbe93d09431cc708221607309cbeafa61` were freshly reopened. All 326 Sol manifest entries, 220 files, modes, hashes, sizes and exact descendant coverage pass. Author source1913/report269 entries also pass, with final1314 input copies matching the live sealed author metadata. Prior independent approvals remain unchanged.

The feature is original UI resource preservation and its separate-target CMake attachment contract. The reference is DJI Studio build1.0.0.30839, `extracted/1.0.0.30839/DJI Studio.exe`, 58,288,312 bytes, SHA256 `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`. No Windows behavior was observed. `VERIFICATION.json`, `BYTE-OBSERVATIONS.json`, `METADATA-VERIFICATION.json`, and the independently authored `verify.py` and `metadata_check.py` give reproducible local read-only observations, exact input hashes and per-alias source locations. No new REA Evidence ID was issued. Reused XOR evidence is prior337/370, functions0x1406853e0 and0x140670e90; this review verifies bytes, not new instruction-level semantics or registration reachability.

## Source and integration observations

All 3,565 original tracked blobs/modes and 3,585 prepared tracked blobs/modes match their exact commits and worktrees. Both worktrees were clean. The original change has exactly1,253 paths, all `gui/original`:1,249 added payload files and four modified bundle files. Every original commit blob/mode is preserved in the prepared tree. Comparing prepared HEAD to approved main plus the exact original resource delta leaves only the added `docs/tasks/original-resource-review.md`; it correctly reserves review and integration without claiming runtime parity. Approved-main handoff additions are carried unchanged. The inherited hosted workflow was not re-reviewed or exercised under this grant.

All1,735 non-resource files from the original base remain byte/mode identical across base, original, approved main and prepared HEAD. Full pins are in `UNCHANGED-APPLICATION-PINS.json`, with the complete four commit inventories in `INTEGRATION-TREES.json`. In particular, the frozen application build inputs are unchanged:

| Path | SHA256 |
| --- | --- |
| README.md | ed176128e4d7dd16f077f617e30474f1d483f0cfc06605b585e37b1cb8b66535 |
| gui/build.py | fa27a5c3ebe06f8d8d27fb18a02b83a50dbedcec7bdf852c898e2e2485f78166 |
| gui/backend-source-manifest.json | f8b70eb52ad55456d26db197b030d309d3bd3991eb27551a2a950003d239d111 |
| gui/CMakeLists.txt | 86c06ccc4df344d5f0c5b78109f5e7120f454872134189d9b7930c3a6485b7cb |
| gui/main.cpp | be8a9576de221ff9b8b7bb442d855877f6d0b8c4ff9bc9ecef0daa6e50d3af4f |
| gui/README.md | 11e2af076b21bbb97ca5fce4fcfe4501499dcbe7005185589fc3823acb4bc6b9 |

## Fresh byte verification

Own decoding independently verifies every1,826 unique QRC alias/payload, including all577 exact base payloads. All1,458 compiled EXE raw ranges were reread from the pinned EXE, with length-prefixed zlib decoding where required, and compared byte-for-byte with the prepared payloads. Exact range offsets, stored lengths and hashes are recorded per alias in `BYTE-OBSERVATIONS.json`.

The original64-byte mask was freshly reconstructed at raw offsets32181440 and32181520 as A[i] XOR B[i mod48], matching SHA256 `4658759753bc29e5a98e025b29fe7fc4c278fdef98e0afeb07192ea957dc1ed3`. Cyclic application to all three pinned encrypted packs reproduces their exact decoded bytes. Own recursive RCC tree decoding verifies369 file occurrences and368 unique pack aliases, including the identical duplicate `/Controls/TextInputOverlay.qml`. This set and the1,458 compiled aliases are disjoint and exactly cover the prepared QRC.

The resulting inventory has410 QML,44 original UIControls QML, four qmldir,1,180 SVG and222 PNG aliases, plus other preserved types including shader and empty PEM. The compiled GUI QRC overlaps exactly1,458 aliases, all byte-identical. Catalog content independently has1,980 top-level keys and16 exact locale keys, including both zh-Hant and zh_Hant. These are recovered static content facts, not evidence of displayed localization or locale selection.

Author and Sol compiled RCC artifacts are byte-identical at15,588,458 bytes, SHA256 `210385d7d5888146c6587d341297c5eb43679bbb9d11881951f7a9830186d5b9`. Own parser decodes all1,826 entries, including572 zstd and1,254 plain entries, and compares each against source. This turn did not recompile RCC; compilation provenance is Sol's sealed independent Qt6.11.2 result, with fresh artifact identity and full independent decoding here.

## Semantic code and CMake evidence

`SEMANTIC-DIFF.patch` preserves the exact helper/documentation diff. Helper lines44-45 add declaration-time target properties for `qrc:/` and `qrc:/qml/Main.qml`. They supply stable target metadata even when the include and attachment occur in different directories. They do not modify a QML engine or launch a shell. The direct-QRC diagnostic now correctly describes1,458 compiled-resource collisions. Attachment still uses definition-directory `CMAKE_CURRENT_FUNCTION_LIST_DIR` at line69; missing/non-executable/undeclared/repeated/direct-QRC target guards remain intact. This helper is an independent packaging design, not a recovered vendor architecture. Source resources are preserved without normalization.

All ten Sol resource-only configure fixtures, their exact logs and result properties were reopened and semantically inspected. Two positives establish exact definition-directory QRC, import/main properties, declaration/attachment state and AUTORCC; eight deliberate failures exercise missing targets, undeclared attachment, direct QRC before declaration/attachment, repeated declaration/attachment and non-executable declaration. The logs and properties support the reported results. No peer script, CMake fixture, executable or runtime was executed by Astra. The sealed Sol configure evidence is retained as prior independent validation; this is not represented as a fresh Astra configure run.

The collision guard checks literal direct `.qrc` source strings at declaration/attachment time. It does not guarantee safety for later additions, generated collections, linked libraries or runtime registrations. The resource README preserves the relevant indirect-resource and original startup/import limitations. The expanded bundle is not attached to the existing GUI in this prepared integration, and application startup code is unchanged.

## Nonblocking qualifications

Final author1314 pins supersede the older1312 prose pins. The final baseline artifact was freshly hashed as `65d6c1b233caabc8d0a650a41a65c6f1a0329ee4b8f585b3eabffa11ffa2a9f1`; no conclusion relies on the malformed earlier baseline hash. Exactly211 inherited `/app_qrc/` provenance rows omit a stored-length field. Their exact offsets, lengths, payload hashes and source bytes are nevertheless present and freshly joined across the compiled identity and final source verification for all1,458 compiled resources. This is a metadata qualification, not a payload gap.

All1,826 final provenance payload hashes, sizes and source artifacts were reopened, with declared pack/node metadata checked. The two inherited qmldir rows use the pinned supplemental schema; the two new non-QML pack rows use plural node/offset fields. Both forms match the independent decoded observations. Two initial metadata-checker schema assumptions failed and are preserved as attempt1/2 source and logs; the corrected third check passes. Read-only discovery failures are preserved in `preflight-failures.txt`. No peer artifact was altered to obtain a passing result.

## Approval boundary

This approval covers exact resource code/source preservation and integration compatibility of the named prepared tree. Full UI/runtime/Windows parity is NOT approved. QML parsing/instantiation, native module/context/controller registration, full imports, original Main startup/show, rendered localization and application failure behavior are unverified. Numeric/media output and file/project compatibility were not exercised or promoted. No required feature is declared complete or reference-verified.

No network, GUI, application runtime, peer script execution, new REA import, application code edit, peer edit or signal occurred. Analysis writes are limited to this assigned directory and addressed bus operations. Actual receipt1358 and progress1361 are distinct from this final approval. Startup/controller reports were not reviewed. Watchdogv1 rejection1355 remains in force; v2 and service verification are outside this grant. Standard/default with Fastfalse was retained as the requested policy with no speed override or worker launch; backend tier/model configuration is not independently exposed by the tools used here.

The finite resource milestone is complete. Root retains the integration action and must preserve these exact approved identities; a changed source or integration tree requires review of its delta. This report and the full artifact manifest are delivered through the actual bus in reply to1357, copying the resource author and independent reviewer.
