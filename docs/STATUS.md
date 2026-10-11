# Current status

The repository is public. PR 1 integrated the complete original resource bundle at
`6f3dc07208bc2dc8026730cebacc2c9aa93af1db` after independent Sol High review and
Astra High verification. All 3,585 tracked files match the approved integration tree.

| Area | State | Next work |
| --- | --- | --- |
| Native CLI and experimental Qt GUI | Implemented in bounded parts | Compare with the pinned Windows build and original media |
| Complete original resource bundle | 1,826 aliases integrated and reviewed; 577 baseline payloads unchanged | Reuse the bundle, do not repeat extraction |
| Original QML inventory | 410 QML aliases recovered | Recover missing native registrations and controllers |
| Original locale catalog | 1,980 keys, 16 locale IDs, 30,537 values recovered | Verify runtime string selection and UI behavior |
| Original Main startup and layout | New static reports under independent review | Resolve the missing native module API contracts |
| Native controller behavior | Partial static findings | Review each bounded contract before implementation |
| Full UI, DLL behavior, project compatibility, processing | Incomplete | Continue evidence-based implementation and reference comparisons |

The current GUI loads the experimental `NativeStitchedFlow.qml` entry. The complete
resource bundle does not establish successful loading of original `Main.qml`.
Resource preservation and runtime equivalence are separate results.

## PR monitoring

Hosted manual checks pass. Automatic PR event runs remain unverified. PR 2 reserves
the trigger correction and must stay in draft until its automatic-run gate passes.
A local read-only watchdog v2 is under independent Sol review after a delivery retry
repair. No continuously running monitor is claimed at this checkpoint. Read open
PR claims before edits and pushes; use a manual hosted check when needed.

## Validation limits

Historical validation includes 184 bounded backend tests and 19 headed GUI cases.
These results apply to their recorded source and fixtures. No feature has a complete
Windows reference comparison. There is no supported percentage for full reverse
engineering or full implementation.

Worker names identify authors, not current running processes. See PR 3 for active
task ownership and progress. See [resource review records](evidence/next-wave/README.md)
for the newly approved resource scope and [historical evidence](evidence/INDEX.md)
for earlier records. The complete local evidence archive is not included.
