Read START-HERE.md, CONTRIBUTING.md, docs/STATUS.md and docs/RESEARCH.md first.

# Working instructions

Read the task scope, contribution rules, current status and research instructions.
Use the assigned tool interface and verify its actual capabilities.
Work only within the declared task and file scope.
Preserve other contributors' files, evidence, processes and analysis sessions.

## Current source

Fetch the target repository main branch at task start and resume.
Check it again before edits, validation and pushes, and after long calls.
Record the repository, worktree, branch, HEAD, fresh main SHA, check time,
ancestry result and clean or dirty status in the PR and comms.
Use a separate owned branch and worktree for source edits.
Preserve commits and uncommitted files before updating your own branch.
Do not reset a peer worktree or force-push reviewed history.
Report a failed remote check as an unverified source base.

## PRs and ownership

Read all open PR claims before work, after long calls and before each push.
Reserve implementation in a draft PR with the owner, task and exact file paths.
Include a short task plan, supporting evidence and a meaningful completion check.
Check the current PR watchdog result before implementation.
Resolve overlapping scopes with the owner through comms before edits.
Keep changes, progress, blockers and review requests in the same task PR.
Update the claim before expanding its file scope.
Do not merge or publish a release without the required review and authorization.

## Comms

Use the addressed project bus for scope reservations, receipts, questions,
findings, blockers, review requests, corrections and handoffs.
Use the PR for the shared source record. Comms does not replace the PR.
Read your inbox at task start, after long tool calls, before changing targets,
before edits and before reporting.
Acknowledge only messages you have read under your own routing identity.
Publish a receipt before work.
Send substantive progress at least every two minutes during active work.
Send results to the task owner and assigned reviewer. Copy the coordinator.
Use --reply-to for answers, reviews and corrections.
Distinguish a receipt, a completed task, evidence approval and feature completion.
State a blocker precisely and continue useful work within the approved scope.
Do not publish credentials or private reasoning.

## Original names and UI

Write GUI application code in Rust and QML.
Do not add C++ application code.

Preserve original names from the source. Do not invent replacement names.
Keep original UI text, labels, resource strings, layouts, interactions and workflows.
Reuse the exact original source and assets where available.
Do not redesign UI or UX to fill an evidence gap.
Keep a missing name or behavior unresolved until the source establishes it.
For a required Rust identifier adaptation, record the exact original name and
source location. Preserve the original name in product-facing text and interfaces.
Do not present research-tool names or independent internal APIs as original DJI names.

## Research and implementation

Prefer REA with Ghidra when it is available.
Read the [REA workflow and benchmark policy](docs/REA-WORKFLOW.md).
Use the latest upstream REA from the [official repository](https://github.com/morluto/rea).
At task start and resume, fetch its default branch and update an owned
installation to the newest upstream commit before new analysis.
Record the upstream commit, package version and running MCP server version.
Preserve other workers' installations and active sessions.
Keep saved evidence pinned to the tool version that produced it.
Verify access and reuse matching saved evidence before an import.
Request a required import or resource grant through comms.
Pin the original build, source hashes, artifacts, function addresses or observation
steps, evidence IDs when available and limitations for each behavioral claim.
Check decompiled results against original bytes where needed.
Separate static facts, observed behavior, native behavior, inference, design
choices and unknowns. Names and strings alone do not prove behavior.
Preserve original artifacts, failed probes and immutable reports.
Use a new additive record to correct a published report.
Use evidence-backed contracts for Rust application changes.
Label independent error handling and implementation choices explicitly.
Use reference fixtures or independently supported contracts as test oracles.
Run checks that are meaningful for the change. Record exact results and limits.

## Review and delivery

Request independent review of the exact candidate commit and evidence packet.
Keep the author and reviewer roles separate. Do not approve your own change.
Correct review defects and obtain review again when the candidate changes.
Verify the reviewed milestone before accepting new claims or publishing a package.
A build or synthetic test does not establish Windows or camera parity.
Mark a feature complete only after its implementation, required checks, independent
review and reproducible reference comparison are complete.
Record UI, processing output, project compatibility and failure behavior separately.
Report unavailable reference inputs without claiming unsupported completion.
Leave a precise handoff with source identities, tests, review disposition,
remaining defects and the next useful task.

## Writing

Use ASD-STE100 Simplified Technical English for all new English text.
Apply this rule to chat, agent messages, documentation, PRs, issues, code comments,
and commit messages.
Use the writing rules and dictionary in the
[official standard](https://www.asd-ste100.org/).

Use short, complete sentences and active voice.
Keep technical terms consistent. Do not use em dashes.
Preserve exact source strings, binary data, addresses and reviewed records.
