# Caller object construction for the stereo-pair path

Root authored this packet alone on 2026-10-13 UTC. Independent review is pending.
This is an additive continuation of `producer-01`. It changes no application code.

## Result

The static construction path and member load now connect to the stereo-pair
caller. Function `0x18019a1e0` loads the pointer at its incoming object's offset
`+0x450`. It passes that pointer to `0x18013cd10`. A saved construction path stores
the result of `0x180134840` at the same owner offset. Its base initializer writes
one zero qword at child offset `+0x24`. That store covers both dwords `+0x24` and
`+0x28`. The earlier producer packet pins the later two `0x780` dword stores.

This is a conditional static join. It does not prove that a live call uses the
object from this construction path, or that no other path replaces the member.
It does not assign units or field names to `+0x24`, `+0x28`, or `0x780`.

## Original byte edges

All addresses refer to DJI Studio 1.0.0.30839 `VinceEditor.dll`. Its size is
10,958,008 bytes. Its SHA-256 is
`9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.

| Address | Static fact |
| --- | --- |
| `0x1801980b8` | The construction path preserves its incoming object pointer in RDI. |
| `0x1801980fe` | It passes literal `0xa50` in ECX to helper `0x18064bb54`. The helper's full allocation and failure contract is outside this packet. |
| `0x18019810d` to `0x180198129` | If the helper result is nonzero, it passes that result in RCX and owner `[+0x448]` in RDX to `0x180134840`. It stores the returned RAX at owner `[+0x450]`. The skipped branch stores zero. |
| `0x18013484a` to `0x18013484d` | The child initializer preserves incoming RCX in RBX and calls `0x1801476a0` with the incoming RCX and RDX. |
| `0x1801476a0`, `0x1801476c5` | The leaf zeros R8, then stores R8 as a qword at `[RCX+0x24]`. This zeros both adjacent dwords. |
| `0x1801476cd` | The same leaf stores its RDX argument at `[RCX+0x30]`. |
| `0x180134c1f` | On normal return, the child initializer copies its saved entry pointer from RBX to RAX. Its intervening callees are not given a general side-effect contract here. |
| `0x18019a203`, `0x18019a228` | The caller saves its incoming owner pointer in RBX, loads owner `[+0x450]`, and skips the child calls if that value is zero. |
| `0x18019a23a`, `0x18019a24c` | It calls two small setters. Their complete reached sequences store EDX at child `+0x760` and `+0x764`, respectively, then return. |
| `0x18019a251` to `0x18019a261` | It restores its saved R9D, R8, and RDX arguments, reloads owner `[+0x450]` into RCX, and directly calls `0x18013cd10`. |
| `0x18013cd75`, `0x18013d187`, `0x18013d18f` | The prior stereo-pair path copies RCX to R15, then writes literal `0x780` to dwords `[R15+0x24]` and `[R15+0x28]`. These anchors were checked again. |

The original RTTI records linked from the three initializer vtable stores contain
`.?AVPanoramaEffect@@`, `.?AVPanoRenderer@@`, and `.?AVRenderer@@`. These exact
strings identify the associated metadata. They do not prove live dispatch,
ownership, image geometry, or field meanings.

## Method and checks

Three complete saved assembly captures are copied unchanged from the earlier
`stitch-mask-provider-producer` packet. Their hashes match its frozen manifest.
Three new captures cover the 177-byte direct caller and the two 7-byte setters.
They use GNU objdump on the original file. No new VinceEditor REA import,
decompilation, or vendor execution occurred. Saved byte evidence is reused here;
no newly loaded image was verified.

`verify.py` checks all 6,532 captured bytes in 1,425 rows, 23 fixed byte anchors,
seven direct call targets, eight exception-table queries, three RTTI records,
and four saved dependency hashes. `VALIDATION.json` records PASS. The leaf
initializer and two setters have no containing exception-table record. Their
captures stop at their reached return instructions. A metadata interval alone
does not prove complete function control flow.

A raw scan found one E8/E9 candidate for `0x18013cd10`, at `0x18019a261`, and no
initialized absolute pointer match. Entry-based disassembly validates that
candidate as a call. These scan results do not exclude indirect calls or computed
references. `WITNESSES.json` records source bytes, file offsets, metadata, and pins.

Reproduce the byte checks without writing to this packet:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 verify.py /path/to/original/VinceEditor.dll
```

The optional `--check-saved-dependencies` also needs the pinned local archive paths.
`SOURCE-CHECKPOINT.json` records the owned Git checkout. `REA-RUNTIME.json` records
the updated local cached REA build and its separate smoke validation. The earlier
60-run benchmark remains tied to its original build. Its timing does not apply
to this new build or this static stitching check.

## Remaining boundary and next step

The outer call at `0x18022864c` passes a pointer saved from helper `0x180281760`
into `0x18019a1e0`. This packet pins those two call edges but does not resolve
that helper's producer or prove the selected live instance. The next bounded
query is that helper's returned pointer and its caller-side source. Preserve
this packet before extending that query.

The constructor's zero store is an event in its static instruction path. This
packet does not prove that zero survives all later calls. The `0x780` values have
no established units here. The packed EIS export body, complete pair schema,
GPU/frame integration, and real camera/Windows comparison remain open. Stitching
is incomplete. The author has not approved this packet, PR48, or a Rust contract.
