# Proposed bounded OSS CRC64 contract

Status: correlated author proposal. Independent approval is required before Rust edits.

Original: DJI Studio build `1.0.0.30839`, `alibabacloud-oss-cpp-sdk.dll`,
3,130,552 bytes, SHA-256
`083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1`.
Image base: `0x180000000`.

## Original-byte facts

The named export `?ComputeCRC64@OSS@AlibabaCloud@@YA_K_KPEAX0@Z` has ordinal
1737 and export RVA `0xc9a0`. E9 rel32 instructions lead through `0x80160`,
`0xd878`, `0x1b4610`, and then to the actual arithmetic body at `0x1b4bc0`.
The body occupies `0x1b4bc0..0x1b4ce4` inclusive. Its unwind metadata splits
its range at `0x1b4c02`; that split does not end the control-flow body.

The named export `?CombineCRC64@OSS@AlibabaCloud@@YA_K_K00@Z` has ordinal
1726 and export RVA `0x55c4`. E9 instructions lead through `0x800a0`,
`0x61bd`, `0x1b4640`, and to arithmetic body `0x1b4850..0x1b4975` inclusive.

`ComputeCRC64` takes the incoming CRC in RCX, byte-buffer address in RDX and
unsigned byte count in R8. `not rcx` at `0x1b4bcf` complements the incoming
CRC. The byte recurrence at `0x1b4bdd..0x1b4bf2` and
`0x1b4cc1..0x1b4cd7` is `table[low8(crc XOR byte)] XOR (crc >> 8)`.
It processes bytes in increasing memory-address order. The final `not rcx`
at `0x1b4cdd` complements the state again. Length zero reads no buffer bytes
and returns the original incoming CRC, including when the buffer is null.

The table address is `0x1802d6aa0`. The initializer at `0x1b4d30` passes this
address to generator `0x1b49c0`. The pointer at `.rdata` RVA `0x211278`
contains `0x18001b9b0`; that stub jumps to `0x1b4d30`. Identification of the
surrounding pointer array as CRT startup is pending provider corroboration.
The table lies in the zero-filled virtual portion of `.data`, not in a baked
original file table. The generator sets base-table entry i by applying eight
right-shift steps to i, XORing `0xC96C5795D7870F42` when the previous low bit
is 1. It derives seven further 256-entry tables by repeated byte recurrences.
The generator occupies `0x1b49c0..0x1b4b4f`. It uses unsigned 64-bit values.

The Compute body first reads individual bytes until the buffer address is
8-byte aligned or length is exhausted. It then XORs each unaligned-free
little-endian qword into state, applies the eight slicing tables to state
bytes 0 through 7, and finishes with individual bytes. Slicing tables map
state byte0 to table7, byte1 to table6, ..., byte7 to table0. This is
mathematically the same byte recurrence eight times. Safe Rust may use the
base-table recurrence for every byte because the observable result is the
same and it avoids native alignment and raw memory hazards.

`CombineCRC64` takes crc1 in RCX, crc2 in RDX, and unsigned len2 in R8.
At `0x1b487d..0x1b4880` it checks all 64 count bits for zero. The zero path
returns crc1 without considering crc2. For nonzero len2 it initializes a
64-column one-zero-bit operator: column0 is `0xC96C5795D7870F42`, columns
1..63 are 1,2,...,1<<62. Helper `0x1b4d40..0x1b4d7d` squares an operator by
applying helper `0x1b4d90..0x1b4da8` to each column. The latter XORs columns
selected by the low-to-high set bits of a 64-bit vector. Two initial squares
form operators for 2 and 4 zero bits. Each loop squares again to produce
8,16,... zero-bit operators, conditionally applies them to crc1 according to
len2's unsigned low bits, and logically shifts len2 right. The final result
is shifted crc1 XOR crc2. No input/output complement occurs in Combine.
It handles full u64 len2 including bit63. These zero-bit operators are linear;
when crc2 was computed from seed0 for the second byte segment, Combine
matches computing both segments from the first segment's original seed.

## Bounded Rust adaptation

Preserve the public original names `ComputeCRC64` and `CombineCRC64` using
`#[allow(non_snake_case)]` with source citations. Use `u64` for every CRC and
Combine byte count. Use `&[u8]` in place of the native `(void*, u64)` pair;
the slice's length defines the byte count. This is an independent Rust
safety policy, not C++ ABI or invalid-pointer equivalence. All seed bit
patterns are supported. Empty slices return the seed. No implicit seed0,
no implicit text encoding, and no data mutation occur. No error return is
needed because the safe slice encodes valid bounded input. The table may
be immutable and generated at compile time rather than initialized by a
mutable C++ process constructor; that is an independent lifecycle choice.
The combine routine uses stack matrices and no heap allocation.

## Required oracles and checks

Obtain actual named-export results under Wine with the original DLL and safe
buffers. Cover all byte values, zero and arbitrary seeds, lengths 0,1,7,8,9,
15,16,17 and larger; every buffer alignment residue 0..7; null plus len0;
incremental segmentation; combine len0 with nonzero crc2; large lengths at
32/63/64-bit boundaries without allocating such input. Record loaded native
runtime dependencies and Wine builtin services. This is Wine evidence and
not Windows equivalence.

Use an independent bitwise polynomial oracle for Compute rather than the
production table and a separately structured polynomial-power oracle for
Combine. Assert valid-segment concatenation with second CRC computed from
seed0. Test full-width u64 lengths, including u64::MAX. Run standalone and
Cargo debug/release tests, rustfmt, Clippy, original artifact hash checks and
exact-candidate independent code review. Full SDK, network methods, timing,
C++ ABI, malformed pointers, UI, project, media and Windows parity are out
of scope.

## Fresh provider corroboration and limitations

New live REA analysis used owned upstream `edf46248f2a44b4e5776518489fee09d0fc4516b`,
package and running MCP server `6.4.0`, Ghidra `12.1.4`, Java21, `-Xmx768M`,
provider startup limit480000ms and correct SDK2.3.1 two-argument client
call timeout600000ms. The whole session held the shared exclusive Ghidra
lock. It freshly imported the original file, did not reuse benchmark snapshots,
and closed its owned image and processes before releasing the lock.

`PROVENANCE.json` pins all six function pseudo/assembly/info/callers facets,
16 provider byte witnesses and their exact original comparison. All47calls
succeeded. The16 ranges contain1139 exact original bytes. The FunctionManager
body agrees with the complete arithmetic and helper ranges above.

The provider Compute pseudocode reads through `ulonglong*` in byte loops.
Those inferred types do not justify qword overreads. Original instructions
load one byte (`movzbl`) in both loops. Rust follows those instructions.
The Combine pseudocode warns that `__security_check_cookie` was replaced
with a security-check-cookie injection. The translated normal-return CRC
contract excludes deliberately corrupted stack cookies and foreign ABI.
FunctionManager signatures remain `undefined FUN_...()`. The actual register
usage and decorated export identity establish this bounded dataflow; this
packet does not recover or claim a public C++ header.

Ghidra xrefs to the initializer pointer and its jump stub are empty. The
byte-backed pointer and stub are preserved, but their enclosing CRT array
classification stays inferred until independently proved. The initializer
and generator body arithmetic are established. The independent original-DLL
oracle owner will separately verify the initialized table and normal exported
calls after DLL loading. The static provider does not execute startup.

Default auto-analysis emits unrelated failed function creation, type and RTTI
messages. `OWNED-ghidra.log` preserves those diagnostics. None changes the
exact original-byte comparison for the six arithmetic/helper bodies. An
original-DLL fixture and independent contract approval are still required.
