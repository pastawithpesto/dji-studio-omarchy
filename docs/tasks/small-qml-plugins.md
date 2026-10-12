# Small Qt QML plugin research

Reserve the three next tied-smallest native DLLs from DJI Studio 1.0.0.30839. Each is 28,856 bytes.

- `qml/Qt/labs/animation/labsanimationplugin.dll`: SHA-256 `4b0be3a96703da2a82b91b34f07a6750e6ffdab6ffb3f3966c997cc648b89425`.
- `qml/Qt/labs/folderlistmodel/qmlfolderlistmodelplugin.dll`: SHA-256 `96d89490eecaf907264fbbb77689f5e5f8a0a50f809f80c842748ef3ebbe7960`.
- `qml/Qt/labs/qmlmodels/labsmodelsplugin.dll`: SHA-256 `58c00865d5e4eceb7c304c0f20f3154aa369ae8f75e2cd97a7452ea55efe9950`.

Use the latest official REA upstream with Ghidra in an owned installation. Preserve exact names and binary source. Reuse matching evidence before import. Hold the exclusive shared import lock with a 768M heap. Capture exports, all provider-discovered native bodies, original bytes, metadata, startup, dependencies and unresolved external boundaries. Check pseudocode against disassembly and original bytes.

Keep raw analysis local under `reconstruction/root-small-qml-plugins-20261012`. Publish selected report and source identities only after independent review. This task owns this plan and `docs/evidence/small-qml-plugins/**`. No native implementation, vendor execution, dashboard publication or main merge is part of this research.

Completion check: original hashes stay unchanged; LLVM and binutils export routes agree; every claimed analyzed range matches original bytes; coverage and missing boundaries are explicit; independent source-evidence review and separate milestone verification pass.

Analysis candidate: 309 provider-discovered executable functions, 318 body ranges and 9 data regions match original bytes. Full raw packet and snapshots remain sealed locally; selected corrected report, indexes and export output are copied into the evidence scope. Initial thunk wording and per-target JSON counts are corrected additively. The report identifies the local registration thunk and its IAT slot precisely. Latest upstream 4573e8cf, package/server 6.4.0 and Ghidra 12.1.4. Independent packet/publication review and separate verification are pending. This is not runtime or application completion.
