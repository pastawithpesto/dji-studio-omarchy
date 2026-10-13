# REA analysis queue integration

The local integration uses the original bugly_extra_handler.dll from DJI Studio
1.0.0.30839. It targets the function at 0x180001010.
The source hash, raw dossier hashes, tool identities and bounded results are in
INTEGRATION.json. Private binaries and complete native analysis remain local.

## Results

The saved dossier run succeeds. A second run uses the same completed attempt.
The full 56-byte body matches the original file at PE offset 1040.
The address mapping was checked separately. It remains supplied provenance in
the queue report. Byte matching does not approve the recovered behavior.

A current upstream REA function query produces a new Ghidra dossier.
The observed Java process uses a 768M heap.
The queue rejects the old expected analysis-profile hash.
The failed attempt retains its complete output and current snapshot.
A separate matching-profile snapshot query succeeds through the repaired adapter.
This last query reuses saved analysis. It is not a new decompilation.

The first command-format failure is also retained.
The adapter now uses the current CLI command with separate option tokens.

## Limits

The queue reports evidence collection, source identity and bounded coverage.
It does not approve behavior contracts or implement DJI application features.
No vendor DLL is executed.
No Windows or camera comparison is performed.
No speed improvement or default optimization adoption is claimed.
Independent exact-candidate review remains a separate recorded decision.
