# Native headless continuation proof

The [selected proof fields](native-continuation-proof.json) record bounded
continuation on 2026-10-12. The original record was checked at
`2026-10-12T15:01:47.597144+00:00`. Its SHA-256 is
`09b36cdd2842f6fc73fe8ed51452403018cfaa1ea15d0089b3a7781c621a0c64`.
This copy preserves the supplied record byte for byte.

Each tool ran as two separate native CLI processes. The second process requested
the ID returned by the first process. It used the same working directory.
Each of the four processes returned a final event and exited with status `0`.

| Tool version | Native session ID | Original working directory |
| --- | --- | --- |
| DSH `0.2.0-rc.2` | `session-66a189f5-74cd-4ee7-b527-12c5da001723` | `/home/violence/Work/dji-headless-evidence-20261012/dsh` |
| Zcode `0.16.9` | `sess_98ed5b7d-761d-4dec-b807-8381c1aafa0e` | `/home/violence/Work/dji-headless-evidence-20261012/zcode` |

Zcode native session metadata selected provider
`account:zai-individual-coding-plan`, model `GLM-5.3-Flash`, and
`reasoningLevel: high`. The second turn passed all six recorded recall checks:
checkpoint, hexadecimal cap, decimal cap, deadline sentinel, remaining sentinel,
and clock counts. The public record contains check results and answer hashes.
It does not contain the answers or raw session events.

DSH configured selection used `deepseek-official`, `deepseek-flash`, and
`reasoningEffort: max`. This selection comes from the versioned overlay and
local selection code. It does not attest the backend model. The resumed turn
produced an additive correction. The record names a separate local contract
approval file. That file is not part of this packet. This workflow packet does
not approve that contract or the separate Rust change.

The supplied record reports that no private reasoning or diagnostics were
exported. Native session stores remain private. The packet contains only
selected result fields, IDs, paths, hashes, model selection, times, and limits.
Use the [session procedure](../../HEADLESS-AGENTS.md) to resume an assigned task.
These IDs do not authorize access to another worker's session.

## Limits

DSH's first turn lacked configured Ghidra access. A separate Sol review used a
newer owned REA installation with fresh provider byte verification. Zcode's
first turn in plan mode had denied remote commands. Root separately checked
the fresh source base, claims, and watchdog. These limits remain in the proof.

Native continuation does not prove a lock across separate processes, current
connector access, Rust behavior, or Windows, camera, GUI, project, or processing
parity. Helper tests do not execute vendor code. Exact candidate review and
milestone verification remain separate gates.
