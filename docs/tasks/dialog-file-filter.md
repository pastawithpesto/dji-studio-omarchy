# Qt Quick file name filter behavior

## Task

Recover a bounded static behavior contract for the original `QQuickFileNameFilter` paths in `Qt6QuickDialogs2Utils.dll`. Focus on index and property behavior, including update and setIndex paths. Resolve only helper and call boundaries required for these claims.

The target is DJI Studio 1.0.0.30839. The original file is `extracted/1.0.0.30839/Qt6QuickDialogs2Utils.dll`. It is 45,240 bytes. Its SHA-256 is `580d8be7657cd4b074b5d4ee43bc8c325d501aea737ef15c13e41f62bd0da263`.

## Scope

Publish this task plan and a bounded report with supporting source-byte evidence under `docs/evidence/dialog-file-filter/`. Preserve exact exported and mangled names, original strings, source offsets, function addresses, full function body ranges, and relevant code and data bytes.

Separate direct static facts from inferred Qt semantics. Record unresolved helper behavior and ABI uncertainty. Do not claim UI behavior or feature completion from names alone. Do not implement C++, Rust, or QML.

## Method

Check saved evidence for a matching source hash before import. Use the current official REA build and one private Ghidra session with the assigned import lock. Inspect each relevant function once. Check pseudocode against assembly and original bytes. Inspect field widths and offsets, branch conditions, updates, returns, signals, and import boundaries. Verify finite branch and layout facts with an independent PE and disassembly oracle where possible. Preserve tool warnings and unknown Qt behavior.

Do not execute the vendor DLL. Do not reuse or interrupt another worker's files, tools, processes, or sessions.

## Completion check

The report must pin the exact DLL hash and build. It must identify every selected function and show its full source range. Each behavior claim must cite a byte-backed path through the relevant condition and operation. It must distinguish static facts, Qt-semantic inference, and unknowns. Independent checks must confirm the source bytes and finite branch or layout facts. The packet must include a manifest of artifact hashes and the exact REA and Ghidra identities. The PR remains a draft pending independent review.
