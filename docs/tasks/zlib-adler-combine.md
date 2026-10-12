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
