# Shipped pthread attribute value functions

Six original attribute getter and setter functions were recovered from
`pthreadVC2.dll` in DJI Studio 1.0.0.30839. Complete provider bodies cover 235
original bytes. A captured-instruction model agrees with separately stated
field and write contracts in 4320 cases. This is a bounded static packet.
The DLL was not executed, and no application code changed.

## Source and selected functions

Original file: `extracted/1.0.0.30839/pthreadVC2.dll`, 68792 bytes.
SHA-256: `66efd5e61c970b73d323efac88c82d7fbe22b842385e55271dd8e5adbf02e71b`.
The independent PE parser and LLVM agree on all 120 named export triples.
The selected exports are direct code entries, not relative export thunks.

| Exact original name | Ordinal | Address | Bytes |
| --- | --- | --- | --- |
| `pthread_attr_getdetachstate` | 4 | `0x1800010c0` | 40 |
| `pthread_attr_getinheritsched` | 5 | `0x1800010f0` | 40 |
| `pthread_attr_getschedpolicy` | 7 | `0x180001150` | 42 |
| `pthread_attr_setdetachstate` | 12 | `0x180001250` | 38 |
| `pthread_attr_setinheritsched` | 13 | `0x180001280` | 38 |
| `pthread_attr_setschedpolicy` | 15 | `0x1800012f0` | 37 |

`SOURCE-MAP.json` gives complete intervals, file offsets, SHA-256 pins, provider
evidence IDs and limitations. The captured bodies have no calls to other
functions or Windows APIs. They read input objects and perform bounded scalar
writes. Other functions and object allocation/destruction are outside this scope.

## Common object check

All six functions take the first argument in RCX. They reject a zero RCX value.
They read a 64-bit object pointer at that address and reject a zero object pointer.
They then compare the first 32 bits of the object with `0xc4c0ffee`.
A failed check returns the numeric value 22 in EAX with no writes.

These checks do not establish that an arbitrary nonzero pointer is mapped or
readable. The recovered packet assumes that each dereferenced pointer supplies
readable memory. A future safe native interface can enforce stronger bounds,
but that would be independent implementation policy.

## Getter behavior

For an accepted object, `pthread_attr_getdetachstate` checks that RDX is nonzero,
copies the 32-bit value at object+`0x18` to the output address, and returns 0.
`pthread_attr_getinheritsched` follows the same path with object+`0x20`.
Neither getter validates that the stored field is 0 or 1 before copying it.

`pthread_attr_getschedpolicy` instead performs an unsigned 64-bit comparison
of RDX with 3. It rejects numeric output addresses 0, 1 and 2, returns 22, and
does not write. For a numerically accepted address it writes a 32-bit zero and
returns 0. It does not load a stored policy field. The address comparison is
an original branch fact, not a guarantee that address 3 is safe to dereference.

The other two getters reject only a zero output address. Their captured
instructions do not reject numeric addresses 1 and 2 before the write.
Aliased outputs can overwrite object fields or the handle storage after all
checks. The packet preserves this behavior rather than assuming non-aliasing.

## Setter behavior

For an accepted object, the detach-state and inherited-scheduling setters use
the low 32 bits of the second argument. An unsigned comparison with 1 accepts
only values 0 and 1. On acceptance, the function writes four bytes at object+
`0x18` or object+`0x20`, respectively, and returns 0. All other 32-bit values
return 22 with no writes. Negative signed bit patterns are rejected by this
unsigned comparison. Upper RDX bits are not part of the comparison or write.

For an accepted object, `pthread_attr_setschedpolicy` performs `NEG EDX`,
`SBB EAX,EAX`, and `AND EAX,0x81`. The low 32-bit input 0 returns 0. Every
nonzero low 32-bit input returns 129. This function does not write the object.
An invalid object still returns 22 before the policy-value operation.

The report preserves numeric values 0, 1, 22 and 129. It does not assign original
enum or error-symbol names without an original header witness. Ghidra inferred
a byte return type for the policy setter, but the observed EAX result is stated
directly. Its inferred type is not presented as a recovered original declaration.

## Verification

The successful isolated baseline used REA commit
`fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d`, package and running MCP server 6.4.0,
Ghidra 12.1.4 and Node 26.9.0. The Ghidra heap limit was 768 MiB. The shared import
lock was held only around the owned session and released after capture.
Original file hashes before and after analysis agree.

All six Ghidra function bodies match the original file ranges. Separate
pseudocode queries match the respective function dossiers. All 85 LLVM
instruction rows match their source bytes without gaps inside the six spans.
Raw dossiers, pseudocode, assembly, snapshot and byte witnesses stay local.

The instruction interpreter models 32-bit register writes, 64-bit pointer
comparisons, flags, conditional branches, memory writes and the NEG/SBB sequence.
A separate contract predicts returns and complete memory changes. All 720
Cartesian cases for each of the six functions agree, for a total of 4320.
The set includes missing handles and objects, incorrect magic values, raw field
values, accepted and rejected setter inputs, upper argument bits, small output
addresses and aliasing with handle or object fields. The input/result digest
and examples are in `VALIDATION.json`.

Synthetic memory maps addresses 1, 2 and 3 solely to check the numeric branches.
Passing those cases does not establish valid Windows pointers. Unmapped-pointer
fault behavior is outside the model. The finite cases are not an exhaustive
proof of every input or runtime environment.

## Preserved failed attempt

The first capture on REA commit `d864ad54717d92fe4b512ce1170717d9904c1f00`
hit the SDK client's default 60-second timeout. The harness supplied timeout as
an ignored third argument to `callTool`. The installed SDK 2.3.1 declaration
requires `callTool(params, options)`. The corrected call supplies a 240-second
limit in the second argument. The owned failed session closed.

`attempt-1` retains the old harness, logs, failure, tool identity and cleanup
records. No semantic claim uses that failed request. The successful current
capture is distinct. The timeout correction is a client API correction, not
an adopted analysis optimization or a performance benchmark.

## Handoff and limits

The bounded packet is submitted for independent review. The research author
does not approve it. Reproduce local model validation with `python3 validate.py`
in `reconstruction/root-pthread-attributes-20261012`. Inspect the pinned original
exports and addresses independently with LLVM. New Ghidra analysis needs the
current upstream check and an owned import slot.

Full original binaries and raw captures stay local. This task publishes only
the report, source map, validation and artifact pins. No implementation,
Windows execution, thread scheduling, complete pthread coverage, DJI call-site
use or application parity is established. No merge or release is requested.
