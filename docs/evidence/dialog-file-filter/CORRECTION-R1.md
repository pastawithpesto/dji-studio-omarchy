# H01 signed-width correction (R1)

This correction supersedes the H01 parse-guard and middle-view start/length wording in [the original report](REPORT.md#filter-list-helper-and-comparison-helpers). Keep that report and its original [manifest](MANIFEST.json) unchanged. Read the original packet together with this correction; R1 narrows only the arithmetic claims for H01 `FUN_180002580`.

## Corrected contract

The H01 machine code does not compare mathematical, unbounded search positions. It operates on the low 32 bits in `EBX` and `EAX`:

1. The first-search result is copied from `RAX` to `RBX` at `0x180002601`. The later `lastIndexOf` result is returned in `EAX` at `0x180002646`. These associations follow the surrounding QChar setup and the Ghidra-labeled call-boundary inventory; the imported implementations remain unresolved.
2. At `0x18000264c`, `DEC EAX` computes `(low32(last) - 1) mod 2^32`. At `0x18000264e`, `TEST EBX, EBX` and `JS` at `0x180002650` leave the parse path when the signed low-32-bit first result is negative.
3. `CMP EBX, EAX` at `0x180002656` followed by signed `JGE` at `0x180002658` leaves the parse path when signed `EBX >= EAX`. The parse path is reached only when `signed32(first) >= 0` and `signed32((low32(last) - 1) mod 2^32) > signed32(first)`.
4. On that path, `SUB EAX, EBX` at `0x18000265e` computes a low-32-bit length. `CDQE` at `0x180002665` sign-extends that 32-bit result to 64 bits. `LEA EAX, [RBX + 1]` at `0x180002671` computes the start in 32 bits; `MOVSXD RCX, EAX` at `0x180002674` sign-extends it. Those values are passed to the `QContainerImplHelper::mid` call at `0x18000267f`.

Thus the bounded machine-level rule is: with `F = low32(first-search result)` and `L = low32(last-search result)`, form `E = (L - 1) mod 2^32`; continue only if `signed32(F) >= 0` and `signed32(F) < signed32(E)`. The start bits are `(F + 1) mod 2^32`, and the length bits are `(E - F) mod 2^32`; both are sign-extended from 32 bits before the call. The guard ensures accepted start and length values are positive signed 32-bit values, while the 32-bit operation widths and wrap points remain part of the captured code contract.

This replaces the unqualified statement that H01 enters the parse block when the first position is nonnegative and less than the last position minus one. It also replaces the unqualified description of the middle-view start with the exact low-32-bit addition and sign extension above.

## Boundary examples

These examples evaluate the captured 32-bit register arithmetic. They do not claim that the imported Qt routines can produce any particular extreme result for a valid string, or establish their runtime semantics.

| First result bits `F` | Last result bits `L` | Endpoint `E = (L-1) mod 2^32` | Signed guard | Start passed | Length passed | Result |
|---:|---:|---:|---|---:|---:|---|
| `0x00000002` | `0x00000009` | `0x00000008` (`8`) | `2 >= 0` and `2 < 8` | `3` | `6` | Parse path |
| `0x80000000` | `0x80000002` | `0x80000001` (`-2147483647`) | First is `-2147483648`; `JS` exits | — | — | Rejected; an unbounded-positive reading would incorrectly accept `2147483648 < 2147483649` |
| `0x7fffffff` | `0x80000001` | `0x80000000` (`-2147483648`) | Signed `0x7fffffff >= 0x80000000` | — | — | Rejected by signed `JGE`; an unbounded-positive comparison would accept `2147483647 < 2147483648` |
| `0x7ffffffe` | `0x80000000` | `0x7fffffff` (`2147483647`) | `2147483646 >= 0` and `< 2147483647` | `0x7fffffff` (`2147483647`) | `1` | Parse path after the 32-bit decrement wrap |

The examples were checked with a separate arithmetic-only model of `u32`, `s32`, and modulo-2^32 addition/subtraction. That model tests the instruction-width rule; it does not execute the DLL or emulate Qt.

## Byte and disassembly witness

The original source is DJI Studio 1.0.0.30839 `Qt6QuickDialogs2Utils.dll`, 45,240 bytes, SHA-256 `580d8be7657cd4b074b5d4ee43bc8c325d501aea737ef15c13e41f62bd0da263`. The complete H01 body is VA `0x180002580–0x1800028a0` inclusive, 801 bytes, SHA-256 `9049e73ee6584ae4c365435a866e60f0283000e99bf74561492c166d57149aba`, as recorded in the unchanged source map.

The corrected instruction span is VA `0x18000264c–0x180002677` inclusive, file offset `0x1a4c`, 44 bytes. Its bytes from the published H01 source-byte witness are:

```text
ff c8 85 db 0f 88 34 02 00 00 3b d8 0f 8d 2c 02
00 00 2b c3 4c 8d 44 24 40 48 98 8d 54 24 48 48
89 44 24 40 8d 43 01 48 63 c8
```

The slice SHA-256 is `5bd37729523c771e0bc543351258a41edba1315131dd4121e3d5f8c415f46a3c`. The slice was independently compared byte-for-byte with the pinned original file. Ghidra's saved attempt-03 listing and LLVM `llvm-objdump` 22.1.8 independently decode the instructions as follows:

```text
0x18000264c: DEC EAX
0x18000264e: TEST EBX, EBX
0x180002650: JS 0x18000288a
0x180002656: CMP EBX, EAX
0x180002658: JGE 0x18000288a
0x18000265e: SUB EAX, EBX
0x180002665: CDQE
0x180002671: LEA EAX, [RBX + 0x1]
0x180002674: MOVSXD RCX, EAX
```

The source map, original manifest, report, original DLL, and attempt-03 raw capture were left unchanged while preparing R1. The separate [revision manifest](REVISION-MANIFEST-R1.json) pins the correction and updated task record alongside the hashes of the original packet artifacts.

## Remaining limits

This correction establishes instruction widths, signed branches, and arithmetic on the register bit patterns. It does not establish the imported search functions' return domain, Qt string behavior, the semantics of `QContainerImplHelper::mid`, valid-input reachability of the boundary examples, or any UI/runtime behavior.
