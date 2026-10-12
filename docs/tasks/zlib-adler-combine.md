# Shipped zlib checksum combination

Owner: @pastawithpesto. Research author: root in the watchdog repair session.

Recover the original `adler32_combine` export in DJI Studio 1.0.0.30839.
The shipped DLL exports this exact name. It does not export
`adler32_combine64`. Do not invent a second export or infer its presence.

The scope is this task file and `docs/evidence/zlib-adler-combine/**`.
No application code, dependency, fixture or shared instruction changes are planned.

Original file: `extracted/1.0.0.30839/zlib.dll`, 140472 bytes.
SHA-256: `45aafddc3e0b0efabe80e75b259e3111d92e6c096c6756e51d8b9221ed3c90ca`.
Export ordinal 2 is at `0x18000100f`. Its relative jump resolves to
`0x180001770`. Recheck these facts from the original PE before analysis.

Preserve the earlier compression-bounds packet. Its selected functions do not
cover checksum combination. Check for a compatible saved analysis before import.
Use an owned current-upstream REA installation and one isolated Ghidra session.
Acquire the shared import lock. Use at most a 768 MiB Ghidra heap.

Capture the function pseudocode, assembly, body ranges and source-byte witnesses.
Recover argument widths, signed length handling, modular arithmetic and return
values only where the original instructions support them. Preserve unknowns.
Compare an instruction-based model with an independent mathematical oracle.
Include boundary inputs and malformed checksum states. Do not execute the DLL.

Keep the full analysis and original-byte captures local. Publish a bounded report,
source map, validation results and artifact pins for independent review.
Send Astra High the exact candidate and sealed local packet. Correct findings
additively and repeat affected review if the candidate changes.

The initial base is freshly fetched main
`48d625376822bdc781bafda7ce36a66b2b5eee2c`, checked at
`2026-10-12T05:58:21Z`. The owned branch is
`research/zlib-adler-combine-20261012`. Its worktree is
`/home/violence/Work/dji-zlib-adler-research-20261012`.

Completion means a reviewed bounded static packet. It does not mean complete zlib,
Windows execution, DJI call-site use, media behavior or application parity.
No merge or release is requested by this research task.

## Delivered packet

The report and source map recover the exported wrapper and checksum helper from
fresh REA/Ghidra evidence. Provider bytes match the original file. The instruction
model and arithmetic agree on 5296 cases. All 49 byte-array concatenation cases
match the independent system zlib oracle. The complete local packet remains at
`reconstruction/root-zlib-adler-combine-20261012`; its initial manifest is
`0b96b36912ee4f971f72989d45d4813eb6a22c9ba17ada60496c3a8e95fb1643`.

The publication corrects one initial padding-count statement additively. The
initial sealed report stays unchanged. Arithmetic and validation did not change.
The published manifest is
`e89ab841e97025235ef08d5294bbfea67781bc1f4e99cbe7fec2c86c8b1be13e`.

The owned branch integrated current main
`88dd9cd280a7a454c536c6d7d1c9d1184d07b65c` without rewriting prior commits.
The packet is submitted for independent Astra High review. No approval or merge
is inferred from its submission.
