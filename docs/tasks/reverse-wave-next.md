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

PR 1 is merged after Sol and Astra approval. Do not repeat resource extraction.
The local watchdog is active and passed Astra operational verification in comms
1387. Hosted automatic event execution remains unverified in PR 2.

WindowPositionDetector analysis passed independent Sol review in comms 1553 and
Astra milestone verification in comms 1580. This PR adds exact selected reports
and a manifest under `docs/evidence/next-wave/window-position`. The full local
evidence archive is not included. Static approval does not approve an adapter.

The original layout, startup, registration, and SDK provenance packets have
bounded milestone approvals. Qt geometry packets passed Sol review in comms
1578 and 1579 and Astra verification in comms 1598 and 1599. Controller packets
remain in review or correction.
New ForwardViewModel work must prove method targets and receiver identity.
GLM and Kimi reports have separate correction and review work.

The worker table above records the initial allocation. It is not a live process
list. Read current PR comments and actual comms receipts before taking a task.
Use the latest verified remote main for new work. Preserve exact vendor pins and
historical reports. Keep this PR in draft while continuation remains open.
