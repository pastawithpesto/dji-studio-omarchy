# Shipped pthread attribute values

Owner: @pastawithpesto. Research author: root in the watchdog repair session.

Recover six attribute value functions from the original `pthreadVC2.dll` in
DJI Studio 1.0.0.30839: `pthread_attr_getdetachstate`,
`pthread_attr_setdetachstate`, `pthread_attr_getinheritsched`,
`pthread_attr_setinheritsched`, `pthread_attr_getschedpolicy`, and
`pthread_attr_setschedpolicy`.

The source file is `extracted/1.0.0.30839/pthreadVC2.dll`, 68792 bytes.
SHA-256: `66efd5e61c970b73d323efac88c82d7fbe22b842385e55271dd8e5adbf02e71b`.
Preserve exact export names. Do not infer enum names from constants alone.

The reserved paths are this task file and
`docs/evidence/pthread-attribute-values/**`. No application code is assigned.
The three Luna authors own separate postproc, atomic-wait and dialog utility DLLs.
The small QML plugin work stays with PR37.

Use fresh current-upstream REA in an owned installation. Reuse matching saved
evidence if available. Acquire the shared Ghidra import lock for one isolated
session with a maximum 768 MiB heap. Preserve peer sessions and original files.

Recover null checks, field offsets, argument widths, accepted integer values,
return codes and write behavior from the actual instructions. Capture complete
function bodies, pseudocode, assembly and original-byte witnesses. Check a
bounded model independently for valid values and error branches. Do not execute
the vendor DLL or call its Windows APIs.

Keep original binaries and raw analysis local. Publish the bounded report,
source map and validation pins in this task PR. Request independent review of
the exact completed candidate. A static packet does not establish full pthread,
thread scheduling, Windows or application parity. No merge or release is requested.

Initial fresh main: `d96457e01f4aa2d6f264a5b9b90942e1aa89e1b4`, checked at
`2026-10-12T06:26:06Z`. Worktree:
`/home/violence/Work/dji-pthread-attributes-research-20261012`.
Branch: `research/pthread-attributes-20261012`.

## Delivered packet

All six selected bodies are recovered with complete source-byte witnesses.
The instruction model passed 4320 synthetic-memory cases. The report preserves
the scheduling-policy getter's numeric output-address threshold, the policy
setter's 129 return, 32-bit accepted-value checks and alias behavior.
The first client-timeout failure stays local with its original harness and logs.
The successful retry uses the documented SDK timeout argument.

The complete raw packet is local at
`reconstruction/root-pthread-attributes-20261012`. The published artifact pins
link its immutable manifest. The candidate remains unapproved pending independent
review. No vendor execution or merge occurred.
