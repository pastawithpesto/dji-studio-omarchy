# PR review and status instructions

Owner: @pastawithpesto. Author: root-pr-review-guide.

## Task

Explain who reviews a PR and who records the required GitHub status.
Add the handoff to the PR template.
Keep the author, independent reviewer, verifier, and coordinator roles separate.

## Scope

- `.github/pull_request_template.md`
- `docs/PR-REVIEW.md`
- `docs/tasks/pr-review-status-instructions.md`

## Source

Repository: `pastawithpesto/dji-studio-omarchy`.
Worktree: `/home/violence/Work/dji-pr-review-instructions`.
Branch: `work/pr-review-instructions-20261012`.
Initial main: `91f1fd620a7a0aea74db49a03be240ee59681401`.
Reuse `AGENTS.md` and `tools/pr_acceptance/README.md`.
The current main requires `agent-review/verified`.
The acceptance worker requires owner approval and an owner-created commit status.

## Completion test

The PR watchdog accepts the claim.
The guide matches the existing review and acceptance rules.
The template links the guide and records the exact reviewed commit.
Independent review checks the exact documentation candidate.
No application behavior, acceptance worker, or branch policy changes.
