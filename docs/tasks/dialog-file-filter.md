# Qt Quick file name filter behavior

## Result

Published a bounded static evidence packet for `QQuickFileNameFilter` from DJI Studio 1.0.0.30839 `Qt6QuickDialogs2Utils.dll`. The source is 45,240 bytes with SHA-256 `580d8be7657cd4b074b5d4ee43bc8c325d501aea737ef15c13e41f62bd0da263`.

The packet captures 17 exact exported functions and three required comparison/filter helpers. It records index storage and signaling, the `update(QString const&)` path, property access and metacall paths, filter-list extraction, comparison helpers, options access, and relevant original metadata and strings. It preserves exact mangled exports, full body ranges, source bytes, import boundaries, Ghidra warnings, and unresolved Qt semantics. It does not implement C++, Rust, or QML and makes no UI or feature-completion claim.

See [the bounded report](../evidence/dialog-file-filter/REPORT.md), [source map](../evidence/dialog-file-filter/SOURCE-MAP.json), [independent verification result](../evidence/dialog-file-filter/INDEPENDENT-VERIFICATION.json), [verification history](../evidence/dialog-file-filter/VERIFICATION-HISTORY.json), and [artifact manifest](../evidence/dialog-file-filter/MANIFEST.json).

Evidence manifest SHA-256: `c3d0c02dc4bda50ee2109084f299c6167942231afce3659dfcdea5ad8b44f943`.

## Correction R1

The original report and its manifest remain unchanged. Read the [H01 signed-width correction](../evidence/dialog-file-filter/CORRECTION-R1.md) with the report: R1 supersedes the earlier H01 parse-guard and middle-view start/length wording with the captured signed low-32-bit guard and wrapped arithmetic. [R2](../evidence/dialog-file-filter/CORRECTION-R2.md) corrects only R1's printed byte-block transcription, endpoint, count, and digest; it preserves R1's arithmetic rule and examples. The [R1 revision manifest](../evidence/dialog-file-filter/REVISION-MANIFEST-R1.json) and [R2 revision manifest](../evidence/dialog-file-filter/REVISION-MANIFEST-R2.json) pin each additive update and the original packet hashes.

## Source and tools

- Repository: `pastawithpesto/dji-studio-omarchy`
- Worktree: `/home/violence/Work/dji-dialogutils-research-20261012`
- Branch: `research/dialog-file-filter-20261012`
- PR: [#41](https://github.com/pastawithpesto/dji-studio-omarchy/pull/41), kept in draft for independent review.
- Source base: `origin/main` `2b189a57e0d9d1facdcbc433a4c74ae0710df8ed`, included by a normal merge.
- Original DLL: `/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/Qt6QuickDialogs2Utils.dll`; hash rechecked after capture and verification.
- REA official upstream commit: `fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d`; package and running server version 6.4.0.
- Ghidra: 12.1.4; Node.js: 26.9.0; Java: 21; Ghidra heap: 768 MiB.
- Independent export oracle: LLVM `llvm-objdump` 22.1.8.

The 17 exported functions were captured in private session attempt 02. The three called helpers and one metadata/string data span were captured in a separate private session, attempt 03. Each session ran alone under the shared import lock, used the pinned original source hash and profile, and was closed before the next session. The vendor DLL was not executed. Complete raw REA dossiers, separate pseudocode and assembly results, request records, and snapshots remain local at `/home/violence/Projects/dji-studio-omarchy/reconstruction/luna-dialogutils-20261012`.

## Validation

The independent verifier passes against the pinned original DLL. It parses all 24 PE exports and agrees with the saved LLVM inventory; checks all 20 complete function byte spans (5,793 bytes) against the original; verifies a 1,088-byte metadata/string span and 23 selected strings; parses 128 runtime-function records and follows nested unwind chains for eight selected body groups; and checks the finite `setIndex` comparison, branch, store, metadata address, and call bytes. The local capture records exact pseudocode equality for all 20 functions. The portable verifier does not recompute that text comparison because the raw pseudocode remains local.

Attempt 01 is preserved. It stopped on a false equality assertion between two separate assembly text renderers; no source-byte or pseudocode mismatch was found. Attempt 02 fixed the invalid check while retaining exact pseudocode comparisons and source-byte checks. The first independent unwind verifier also stopped on a nested chained record; the corrected recursive parser passes. Both failures and corrections are recorded without replacing the original attempts.

The verifier and evidence manifest provide reproducible output and artifact hashes. The source hash stayed unchanged. Analysis remains limited to selected native bodies; external Qt implementations, unresolved container and string semantics, runtime behavior, and application behavior remain unverified.

## Scope and review

This PR reserves only `docs/tasks/dialog-file-filter.md` and `docs/evidence/dialog-file-filter/**`. The open-claim scan found the other active PR paths disjoint. The branch includes current main and its published changes stay within that claim. The PR remains a draft for independent Sol review. No approval, merge, or release is requested.
