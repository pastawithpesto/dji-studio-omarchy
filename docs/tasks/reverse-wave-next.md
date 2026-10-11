# Continue reverse engineering and PR monitoring

Owner: @pastawithpesto

Reserve `docs/evidence/next-wave/**`, this task file, `START-HERE.md`,
`CONTRIBUTING.md`, `docs/STATUS.md`, and `docs/RESEARCH.md` for reviewed handoff
records and current public status.
Local work uses separate directories in the original project workspace.

| Worker | Task | Local output |
| --- | --- | --- |
| Sol High 1 | Review the existing complete resource bundle for PR 1 | sol-ui-independent-review/next-wave/resources |
| Sol High 2 | Diagnose automatic PR events and provide a working read-only local watchdog | sol-review/next-wave/watchdog |
| Luna High B1 | Complete the requested original layout corrections | luna-review/luna-b-1/next-wave/layout |
| Luna High B3 | Resolve the next ProjectStateController native behavior gap | luna-review/luna-b-3/next-wave/controller |
| Luna High A2 | Map native controller dependencies for original QML startup | luna-review/luna-a-2/next-wave/startup |
| GLM 5.3 Flash High | Check quota and accept a separate analysis scope when available | glm-review/next-wave |

All Codex workers use High reasoning, Standard/default mode, and Fast mode disabled.
Run workers in waves within the session limit. Queued work is not running work.
Publish receipts, findings, blockers, and handoffs through the addressed local bus.
Root records shared progress in the PR. Do not repeat completed resource extraction.

Keep PR 1 as the resource integration reservation. Keep PR 2 as the hosted trigger
fix reservation. This PR claims new handoff records, not those implementation files.
Require independent Sol review and Astra High verification before a new milestone.

## Current continuation

PR 1 is merged after Sol and Astra approval. The exact reports are included in
`docs/evidence/next-wave`. Do not repeat resource extraction.

Watchdog v2 passed independent Sol review and root verified its running process,
advancing heartbeats and actual comms delivery. Astra operational verification is
pending. A Sol High worker is reviewing the completed startup/layout reports. Luna High is recovering missing Main native registration records in
`luna-review/luna-a-2/next-wave/main-registration`. This uses existing saved
RAE/Ghidra evidence and pinned original bytes. GLM availability remains quota
limited at the latest UI observation. These tasks use separate local output paths.
