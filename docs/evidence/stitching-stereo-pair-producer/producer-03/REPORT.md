# Outer object getter and selected-function boundary

Root continued alone at the user's request on 2026-10-13 UTC. This packet extends
`producer-02` without changing it. Independent review is pending.

## Result

The outer stereo-pair path gets its owner pointer from member `+0x88` of its
incoming object. The getter at `0x180281760` is exactly eight bytes:
`mov rax,[rcx+0x88]; ret`. It has no containing exception-table record.

One setup path supplies that member through a registered function. It reads the
original property string `effect`, passes the returned pointer to a factory,
and stores the factory result through writer `0x1802818a0`. The factory queries
`mlt_properties_get_data` and tail-jumps through the returned pointer when it is
nonzero. The selected registered function remains unresolved.

This moves the boundary from an unknown getter to a specific property lookup
and indirect function selection. It does not prove that the selected function
is the constructor wrapper from producer-02.

## Static edges

Original build: DJI Studio 1.0.0.30839. File: `VinceEditor.dll`, 10,958,008 bytes.
SHA-256: `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.

| Original address | Static fact |
| --- | --- |
| `0x1802282bd`, `0x180228325` | The outer caller saves incoming RCX in R12 and later passes R12 to the getter. |
| `0x180228328`, `0x18022832d` | It calls `0x180281760` and saves the returned pointer in R15. |
| `0x180281760` | The getter returns the qword at `[RCX+0x88]`. |
| `0x180228615`, `0x180228649`, `0x18022864c` | The selected outer branch checks R15, then passes R15 in RCX to `0x18019a1e0`. Producer-02 covers that function's child member load and call to `0x18013cd10`. |
| `0x18022819d` to `0x1802281a8` | Setup `0x180228190` saves its incoming object in RBX and calls the getter. A nonzero result skips the construction sequence. |
| `0x1802281ae` to `0x1802281b8` | The zero branch passes the saved object and original `effect` string to the `mlt_properties_get` import thunk. |
| `0x1802281bd` to `0x1802281cd` | It passes the returned pointer in RCX and zero in EDX to `0x18026d520`. It then passes that result in RDX, with the saved object in RCX, to `0x1802818a0`. |
| `0x1802818a6` | The writer stores incoming RDX at `[RCX+0x88]` before its later event-related calls. |
| `0x18026d530`, `0x18026d542` | The factory reads global qword `0x180a175c8`. If nonzero, it passes that value, the saved incoming RCX, and zero in R8D to `mlt_properties_get_data`. |
| `0x18026d54c` to `0x18026d55c` | If the lookup result is nonzero, the factory restores its two incoming arguments and tail-jumps through the returned pointer. |
| `0x18026d55f` to `0x18026d56b` | If the global or lookup result is zero, the factory returns zero. |

The writer also references `mlt_service_profile`, `mlt_events_listen`,
`mlt_event_inc_ref`, and `mlt_event_close`. Its registration argument includes
original string `render-context-will-destroyed` and callback address
`0x180281690`. The import names and argument bytes are facts. This packet does
not recover callback execution, ownership, replacement timing, or destruction
behavior. In particular, the initial member store does not prove that its value
survives all imported calls.

## Validation and limits

Five offline objdump captures contain 1,424 original bytes in 344 byte rows.
The verifier also checks 13 fixed anchors, seven direct calls, five exception
metadata queries, six exact import identities, two original strings, and all
14 files covered by the producer-02 manifest. All checks pass. A changed expected
anchor in an owned temporary copy was rejected. Original files were not changed.

The outer capture is a prefix from `0x180228260` through exclusive
`0x180228656`. It includes branches to addresses outside that capture. It is
not complete control-flow coverage. The writer, setup, and factory captures
span their recorded exception intervals. The factory's nonzero path ends in an
indirect tail jump. Metadata bounds alone do not prove all possible behavior.

The initial getter metadata query found no record. A bounded navigation window
included padding and part of a neighboring function. The adopted getter capture
stops at exclusive `0x180281768`; no adjacent bytes support its behavior. The
private probe log also retains a failed display command with a mistyped filename.
Neither probe failure changed the original source or the final byte checks.

No new REA import, decompilation, or vendor execution occurred. The updated local
REA runtime and its separate cold/warm smoke are pinned in producer-02. This
packet does not reassign the historical benchmark timing to that build.

Reproduce from the published adjacent packets:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 verify.py /path/to/original/VinceEditor.dll
```

`--prior-packet /path/to/producer-02` overrides the adjacent packet path.
`WITNESSES.json` contains the original-byte and import witnesses.
`VALIDATION.json` records author validation. It is not independent approval.

## Next boundary

Trace the writer and initialization of global `0x180a175c8`, then the exact
registration for the property key supplied by the selected `effect` value.
A matching name alone is insufficient. A future packet must prove the stored
function pointer and its selected call edge before joining it to the constructor
at `0x180198080` or its wrapper at `0x180266b30`.

The current packet does not prove which setup path is invoked for a live frame,
that the setup and outer caller receive the same live object, or that later
callbacks leave the member unchanged. Full EIS math, field units, pixel layout,
GPU integration, and Windows/camera parity remain open. Stitching is incomplete.
