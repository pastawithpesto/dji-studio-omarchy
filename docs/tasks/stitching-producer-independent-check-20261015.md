# Independent check of the stitching producer records

Owner: `pastawithpesto`.

Review PR 48 at `78d8180533345ad021cf3f04dc05e3fd6294ae52`.
The producer-02 and producer-03 records have author checks only.
Check their byte records, source identity, fixed anchors and stated limits.
Keep the original PR and all historical records unchanged.

## File scope

- `docs/tasks/stitching-producer-independent-check-20261015.md`
- `docs/evidence/stitching-producer-independent-check-20261015/**`

## Plan

1. Reserve this separate review scope in a draft PR.
2. Wait for a successful PR claim check.
3. Replay both exact evidence packets in an isolated checkout.
4. Check the source hashes and instruction bytes against available original files.
5. Challenge each verifier with changed input in temporary copies.
6. Obtain independent Sol High review of the exact target and checks.
7. Obtain Astra High verification of the same bounded result.
8. Record the verdict, reproducible commands, defects and remaining limits.

## Completion check

The review record must identify the exact candidate and current main.
It must include passing replay results and the results of changed-input checks.
The byte comparison must identify the original file hashes and checked ranges.
Any unavailable original file or unresolved claim must remain explicit.
Independent reviewers must state their verdicts and their exact candidate.
This task does not establish stitching, camera, Windows or GUI parity.
It does not authorize a merge or a change to the original evidence packet.

## Source checkpoint

- Repository: `https://github.com/pastawithpesto/dji-studio-omarchy.git`
- Worktree: `/home/violence/Work/dji-active-work-20261015`
- Branch: `review/stitching-producer-checks-20261015`
- Initial HEAD and fetched main: `d922d46337150db102cef675073cfa392ef92bbc`
- Initial ancestry: current main is an ancestor of the task branch.
- Initial worktree state: clean before this plan.

## Progress

Plan only. Independent checks have not started.
