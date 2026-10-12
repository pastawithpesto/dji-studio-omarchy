# Current status

The repository is public. PR 1 integrated the complete original resource bundle at
`6f3dc07208bc2dc8026730cebacc2c9aa93af1db` after independent Sol High review and
Astra High verification. The PR1 integration check verified all 3,585 files in
that recorded tree. This historical count does not describe later main revisions.

| Area | State | Next work |
| --- | --- | --- |
| Native CLI and Rust Qt host | Implemented in bounded parts | Implement missing original native services and compare with the pinned Windows build |
| Complete original resource bundle | 1,826 aliases integrated and reviewed; 577 baseline payloads unchanged | Reuse the bundle, do not repeat extraction |
| Original QML inventory | 410 QML aliases recovered | Recover missing native registrations and controllers |
| Original locale catalog | 1,980 keys, 16 locale IDs, 30,537 values recovered | Verify runtime string selection and UI behavior |
| Original Main startup and layout | Bounded static layout, startup, and registration reports passed Sol and Astra review | Implement and validate the remaining native module API contracts |
| Native controller behavior | Window positioning static analysis passed Sol and Astra review; other contracts remain partial | Review each bounded contract before implementation |
| Full UI, DLL behavior, project compatibility, processing | Incomplete | Continue evidence-based implementation and reference comparisons |

The Rust host attempts to load the exact original `Main.qml`. The custom C++ host
and experimental `NativeStitchedFlow.qml` entry have been removed from the current
source. Local Qt 6.11.2 reports ten missing native modules. Full original GUI
startup remains incomplete. Resource preservation and runtime equivalence are
separate results. CXX-Qt generates C++ binding code; application source is Rust
and QML. The historical validation below applies to its recorded source only.

## PR monitoring

Hosted manual and automatic checks have passed. The existing read-only
`pull_request_target` trigger is verified by
[run38194148483](https://github.com/pastawithpesto/dji-studio-omarchy/actions/runs/38194148483)
on2026-10-12 for PR28 head `0813f8e3ec1c6126c2f46c57a2e8bdd2ee01b607`.
PR2 records the additive correction to its earlier unverified status. Read the
latest check on each current candidate; an old successful snapshot is insufficient.
The local read-only watchdog v2 passed independent Sol review and was observed as
`dji-pr-watchdog-next-wave.service` on the maintainer host. Root verified two
advancing healthy continuous heartbeats and actual comms delivery on 2026-10-11.
It polls every 30 seconds when healthy and backs off on failures. Monitoring
depends on that user service and API access. Astra approved this bounded operation
in comms 1387. Read open PR claims before edits and pushes. Use a manual hosted
check when needed.

## Validation limits

Historical validation includes 184 bounded backend tests and 19 headed GUI cases.
These results apply to their recorded source and fixtures. No feature has a complete
Windows reference comparison. There is no supported percentage for full reverse
engineering or full implementation.

Worker names identify authors, not current running processes. See PR 3 for active
task ownership and progress. See [resource review records](evidence/next-wave/README.md)
for the approved resource scope and [historical evidence](evidence/INDEX.md)
for earlier records. The complete local evidence archive is not included.

## Reverse engineering checkpoint

The [window positioning packet](evidence/next-wave/window-position/README.md)
passed independent Sol review and Astra milestone verification. It covers three
original routines. It does not establish native execution or Windows parity.

Sol approved the separate Qt6Gui geometry and Qt6Core rectangle packets in comms
1578 and 1579. Astra verified these separate static milestones in comms 1598 and
1599. Controller enum, helper, proxy predicate, and constructor packets have
separate reviews.
The helper report needs an explicit correction to an older comparison claim.
Preserve historical reports and apply later corrections as separate records.

GLM completed its controller report, but an audit requires corrections. Kimi
completed a menu audit, but independent review remains pending. These statements
record handoffs, not current process activity. See PR 3 for the current task queue.

The local PR acceptance service is enabled for eligible PRs from `revmnds` after
required review and current-head checks. Sol and Astra approved its source and
bounded operation. No real merge of a `revmnds` PR has been observed. See
[acceptance rules](../tools/pr_acceptance/README.md) for gates and limits.
