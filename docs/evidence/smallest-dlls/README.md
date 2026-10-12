# Smallest DLL static recovery

Original distribution: DJI Studio 1.0.0.30839. All original names and source
identities remain exact. Official REA upstream a1b5d51a, package 6.4.0 and
Ghidra 12.1.4 produced the local raw capture.

- 41 API-set family DLLs: 2,960 exact original forwarders. The family includes
  the 65,576-byte crt-private DLL. This is a related-family selection.
- msvcp140_codecvt_ids.dll: 21,544 bytes, four original data identifiers,
  53 captured native bodies and 55 verified byte ranges.
- msvcp140_1.dll: 25,136 bytes, seven original memory-resource APIs,
  93 native bodies and 97 verified byte ranges.

The two non-api files are the smallest original non-api DLLs. Their 146 native
function bodies contain 152 captured inclusive ranges totaling 6,983 bytes.
Original byte checks, independent export tools and saved instruction witnesses
support the bounded static findings.

Read [scope clarification](SCOPE-CLARIFICATION.json) and
[count correction](COUNT-CORRECTION.json) with the immutable initial
[report](REPORT.md) and [findings](FINDINGS.json). The initial report is preserved
as evidence history. Its final 146-ranges wording requires the count correction.

Independent Sol review approved 72 static claim rows. One original wording
finding is resolved only by the pinned correction. Five broader obligations
remain unresolved. [Independent review](INDEPENDENT-REVIEW.md) and
[static milestone](MILESTONE-REVIEW.md) record the exact boundary. Milestone PASS
certifies the combined static evidence, not a later publication commit.

Full CRT semantics, C++ types and ABI, consumer invariants, external Windows
behavior, Rust reconstruction, media, UI, project and failure parity remain
outside this accepted boundary. No original DLL was executed for this task.

Full raw provider dossiers, byte witnesses, original disassembly and matching
snapshots remain local at reconstruction/root-smallest-dlls-20261012. The source
DLLs and full snapshots are not included here. The copy manifest pins these
selected files exactly to the preserved local reports and review records.
