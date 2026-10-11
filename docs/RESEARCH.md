# Reverse engineering procedure

Use RAE with Ghidra where available. Verify the connector, version, and access
before you assign a task. Tool names and sessions depend on the local setup.
Do not assume that another computer has the same RAE service.

1. Read open PR claims and the evidence index. Reserve one precise target.
2. Pin the binary build and SHA-256. Check that the evidence uses the same file.
3. Reuse matching Ghidra projects, RAE sessions, snapshots, and exported evidence.
   Ask the owner before you import a binary again. Do not stop another session.
4. Resolve callers, imports, exports, thunks, types, and units as needed.
   Check decompiled results against original bytes and disassembly.
5. Save source identity, function addresses, evidence IDs, commands, results,
   failed queries, and limits. Do not treat bad-data placeholders as valid code.
6. Propose a bounded behavior contract. Obtain review before implementation.
7. Compare the native behavior with the pinned Windows reference and real media.
   Track UI, processing output, project compatibility, and failures separately.

| Source, build 1.0.0.30839 | SHA-256 |
| --- | --- |
| DJI Studio.exe | `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4` |
| VinceEditor.dll | `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42` |
| nle_core.dll | `3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1` |

The public repository contains source, recovered resources, fixtures, and selected
handoff records. Original executables, DLLs, full Ghidra projects, models, and the
complete local evidence archive are not included. Request a required artifact from
the maintainer by path and SHA-256 before you repeat analysis. Some historical
records refer to paths in the original workspace. Those paths are not clone paths.

Use the [official Ghidra project](https://github.com/NationalSecurityAgency/ghidra)
for installation and tool documentation. Preserve original reference data exactly.
