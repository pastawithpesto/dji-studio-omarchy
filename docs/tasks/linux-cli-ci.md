# Verify the Linux CLI in GitHub Actions

Owner: @revmnds. Author: root.

## Task

Add one GitHub Actions workflow for the current Linux CLI. Build the locked Rust source. Run the full Rust test suite. Export a short synthetic video that is already stitched. Check the output codec and frame size with FFprobe.

## Scope

- `.github/workflows/linux-cli-ci.yml`
- `docs/tasks/linux-cli-ci.md`

These paths have no open PR claim at the reservation check. Do not change application source or another PR scope.

## Source

Repository: `pastawithpesto/dji-studio-omarchy`.

Worktree: `C:/Users/svg-9/Desktop/dji-studio-linux-cli-ci-20261011`.

Branch: `work/linux-cli-ci-20261011`.

Initial HEAD and verified remote main: `91f1fd620a7a0aea74db49a03be240ee59681401`.

Remote main check: `2026-10-12 01:36 UTC`. Main is an ancestor. The worktree was clean before this plan.

## Completion test

The PR watchdog must accept the claim. The hosted workflow must pass from the exact candidate commit. The workflow must show a locked build, the Rust tests, an FFmpeg export, and an FFprobe output check. Obtain independent code review and milestone verification. Keep the PR in draft until these checks finish.

The synthetic export checks a bounded Linux CLI path. It does not prove camera input, Windows behavior, project support, the original GUI, or vendor parity.
