# Independent DSH R1 approval

Verdict: approve the corrected bounded contract for Rust implementation.
Reviewer: /root/sol61_atomic_contract. The reviewer did not author the DSH
report or the Rust candidate and made no application source edits.

The active DSH evidence is the preserved `FINDINGS.md` plus additive
`CORRECTION-R1.md`. The report SHA-256 remains
`ecb83d11d0fea9a406a2b99055f81c8ef6785cfba6f062937bf4ccd2466c293a`.
The correction SHA-256 is
`6216e596ea34b262a38499e3002d11fcf00e0d59288ad61d9925acb073086d18`.
The correction manifest SHA-256 is
`f83d6cc785fda694ebe2308c001475b6502f043a5dc338718fc621f7a46e3bb9`.

All three corrections pass. The export address table slots are correctly
identified at `0x180006660` and `0x180006664`. The other packed DATA reference
roles remain unknown. The return test now checks zero-extended EAX result bits
with the approved independent `u64` API. The function bodies are individually
contiguous and do not overlap, but they have a 15-byte gap between them.
The reviewer checked the gap bytes directly in the original file.

All four correction manifest links match their files. All 18 first-turn
manifest files retain their exact original hashes. The full original source
hash, the EAT slot bytes, and the gap bytes match the corrected report.
`DSH-R1-check.json` records these checks. The prior original-byte review,
6,654-vector reproduction, and seven passing scratch model tests remain valid.
The latest owned REA provider verification is recorded separately in
`LATEST-RESTORE-REVIEW.md`.

Implement the exact two export names with an injected `FnMut() -> u64` clock
and `u64` observed RAX result bits. Keep sentinel short circuits, exactly one
finite-path clock call, wrapping addition, unsigned comparison, and the
`0x337f9800` cap. A Rust candidate still needs exact-commit review and separate
milestone verification. This approval does not establish formal C++ types,
Windows ABI, Linux clock equivalence, wait loops, wakeups, whole DLL behavior,
vendor execution, or application parity.
