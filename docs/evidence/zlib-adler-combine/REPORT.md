# Shipped zlib checksum combination

The original `adler32_combine` function combines two 32-bit checksum values.
Its exported wrapper takes a signed 32-bit length. A negative length returns
`0xffffffff`. For a nonnegative length, the helper applies arithmetic with
modulus 65521 and fixed conditional reductions. This is bounded static recovery.
The vendor DLL was not executed.

## Source and exact names

Source: DJI Studio 1.0.0.30839, `extracted/1.0.0.30839/zlib.dll`, 140472 bytes.
SHA-256: `45aafddc3e0b0efabe80e75b259e3111d92e6c096c6756e51d8b9221ed3c90ca`.

An independent PE reader and LLVM agree on all 86 export name, ordinal and RVA
triples. Export ordinal 2 is exactly `adler32_combine`. The DLL does not export
`adler32_combine64`. That statement covers the complete named export inventory.
It does not assign a name to an unexported entry or establish all internal uses.

| Capture | Address | File offset | Bytes | SHA-256 |
| --- | --- | --- | --- | --- |
| Export jump | `0x18000100f` | 1039 | 5 | `23fab2fd7a2b98d9656843d5cbe4ef678ace8421b61a165557bc590e69483507` |
| Signed length wrapper | `0x180001770` | 2928 | 8 | `8d0f909def12365826099e38022449d2dca73fa2552de5a1d7a4679a37c1ca45` |
| Combination helper | `0x180001790` | 2960 | 218 | `f270dac7a8e35efb169710d855b7fc22409c3c92470c781905f1e518ec0f1a51` |

The export is a relative jump to the wrapper. The wrapper executes
`movslq %r8d, %r8`, then jumps to the helper. It sign-extends the low 32 bits
of the third argument. The helper reads the low 32 bits of the first two
arguments through ECX and EDX. It returns its result in EAX. No checksum buffer
is read. The captured memory operations only save and restore RBX on the stack.

Ghidra inferred `void` for the wrapper. That inferred return type is not adopted.
The original terminal jump transfers to a helper that returns EAX to the caller.
The model follows that control flow. An observed-width reconstruction contract
is `(u32, u32, i32) -> u32`; this is a proposed native signature, not a recovered
original header declaration or a complete ABI claim.

## Recovered arithmetic

Let `P = 65521`, and let `a` and `b` be raw 32-bit values. Let `n` be the
signed 32-bit length after the exported wrapper. For `n < 0`, return
`0xffffffff`. Otherwise, use the following equations and ordered reductions:

```text
r = n % P
s1 = (a & 65535) + (b & 65535) + P - 1
s2 = (r * (a & 65535)) % P + (a >> 16) + (b >> 16) + P - r
if s1 >= P: s1 -= P
if s1 >= P: s1 -= P
if s2 >= 2*P: s2 -= 2*P
if s2 >= P: s2 -= P
return (s1 | (s2 << 16)) modulo 2^32
```

The negative check is at `0x18000179d` through `0x1800017ac`. The helper obtains
the length remainder through an unsigned multiply with
`0x000f00e10d2fc5cd`, shifts, and a multiplication by `0xfff1`. It obtains the
product remainder with the 32-bit reciprocal `0x80078071`. The conditional
reductions use unsigned comparisons and conditional moves at `0x180001822`
through `0x180001863`. The final shift and OR form the 32-bit result.

For checksum halves in `[0, P)`, this recovers the usual concatenation relation:
the low half is `(s1_a + s1_b - 1) mod P`; the high half is
`(s2_a + s2_b + n*(s1_a - 1)) mod P`. The initial checksum seed is 1 in the
independent byte-array oracle. This relation is derived from the captured
arithmetic. It is not evidence that DJI calls this export on a particular path.

Do not replace the ordered reductions with unrestricted modulo operations for
arbitrary malformed checksum values. The original function does not validate
that the supplied halves are in `[0, P)`. Its final OR does not mask `s1` to
16 bits. For example, two `0xffffffff` values and length 0 return `0x001d000c`
in the instruction model. This raw-state behavior is retained explicitly.
Length 0 also does not validate that `b` is the empty-input checksum.

## Static evidence and verification

Fresh analysis used owned REA upstream commit
`69e097a8ca256ab97ee4b2883739447784a5f90e`, package and running MCP server
6.4.0, Ghidra 12.1.4, Node 26.9.0 and a 768 MiB Ghidra heap limit.
The shared import lock was held for the isolated session. The session closed
and produced a snapshot. No peer installation, process or session changed.

REA captured a complete 8-byte wrapper body and 218-byte helper body. Each
provider byte range matches the pinned original file. Separate pseudocode
queries match the respective analysis dossiers. Raw pseudocode, assembly,
tool responses, snapshot and source-byte witnesses stay in the local packet.
Provider evidence IDs and limitations are preserved in `SOURCE-MAP.json`.
The prior compression-bounds packet remains unchanged.

`validate.py` checks 75 captured instruction rows against the original file.
The two modeled spans contain 55 instruction rows. The intervening 24 bytes
contain 19 `int3` padding bytes and a separate 5-byte relative jump at
`0x180001780`. That unexported entry is not assigned an original function name.
The model executes only the 8-byte wrapper and 218-byte helper spans.
It interprets register widths, sign extension, unsigned multiplication,
comparisons, conditional moves, jumps and return. It does not load the DLL.

All 1200 boundary Cartesian cases and 4096 deterministic random cases agree
with the recovered arithmetic. The boundary set includes zero, modulus
transitions, the largest positive signed length, negative length bit patterns,
and malformed checksum fields. The random seed and complete input digest are
in `VALIDATION.json`. This finite test set is not an exhaustive input proof.

All 49 pairs of seven byte-array fixtures match independent system
`zlib.adler32(left + right)` results. Fixtures include empty inputs, zero bytes,
all 256 byte values, repeated 255 bytes and a 75300-byte input. This test checks
the recovered combination model against actual byte-array concatenation. The
oracle is the system zlib, not the shipped DLL or a Windows execution result.

## Review handoff and limits

The packet is ready for an independent Astra High review. The research author
does not approve it. The PR contains only this task plan, bounded report, source
map, validation results and artifact pins. Full raw analysis remains local.

Reproduce local static validation with `python3 validate.py` in
`reconstruction/root-zlib-adler-combine-20261012`. Inspect the original file with
`llvm-readobj --coff-exports` and `llvm-objdump -d` at the pinned addresses.
New Ghidra analysis requires the current upstream check and an owned import slot.
Do not run the import harness in a peer session or overwrite a sealed packet.

Unverified: vendor execution, complete internal call-site reachability,
all unexported entry semantics, complete zlib coverage, Windows behavior,
compression output, camera media, GPU or application parity. No security impact,
new application implementation, merge or release is claimed.

This publication report corrects the initial local report padding count. The
initial sealed packet stays unchanged. `PUBLICATION-CORRECTION.json` records the
exact old and new statements. Arithmetic and validation results are unchanged.
