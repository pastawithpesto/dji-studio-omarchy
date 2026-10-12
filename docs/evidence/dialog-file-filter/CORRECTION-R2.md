# H01 byte-span transcription correction (R2)

This R2 addendum corrects only the byte-block, endpoint, byte-count, and digest printed in [R1](CORRECTION-R1.md). R1's signed-width arithmetic rule and boundary examples remain unchanged. Read R1 with this addendum for the complete correction to the H01 paragraph in the original [report](REPORT.md#filter-list-helper-and-comparison-helpers).

## Corrected byte witness

The exact instruction span is VA `0x18000264c–0x180002676` inclusive, 43 bytes, at source file offset `0x1a4c`. Its SHA-256 is `4a2901e3091bcff3ebd228dfa910d02c18c631cc2000499741dca24e336f2043`. The block below was generated directly from that source slice; parsing it with `bytes.fromhex` round-trips to the same 43 source bytes and the matching 43-byte slice in `SOURCE-MAP.json`.

```text
ff c8 85 db 0f 88 34 02 00 00 3b d8 0f 8d 2c 02
00 00 2b c3 4c 8d 44 24 40 48 98 48 8d 54 24 48
48 89 44 24 40 8d 43 01 48 63 c8
```

R1's printed block omitted the `0x48` REX prefix at `0x180002667` (`LEA RDX, [RSP + 0x48]`). Its stated 44-byte count and digest used a slice extending one byte beyond this instruction span: byte `0x48` at `0x180002677` begins the following `MOV qword ptr [RSP + 0x48], RCX`, which is not part of the corrected span. The full corrected instruction span ends with `48 63 c8`, the three bytes of `MOVSXD RCX, EAX` at `0x180002674–0x180002676`.

The saved attempt-03 Ghidra listing and LLVM `llvm-objdump` 22.1.8 decode the same instruction boundaries. R2 does not revise R1's arithmetic interpretation, the original report, the source map, the original manifest, or R1's correction and revision manifest. No new Ghidra import or DLL execution was performed.

See [revision manifest R2](REVISION-MANIFEST-R2.json) for hashes of this addendum, the updated task record, and all preserved packet revisions.
