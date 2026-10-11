# Agent instructions

Read START-HERE.md, CONTRIBUTING.md, docs/STATUS.md, and docs/RESEARCH.md first.

- Reserve the task in a draft PR before implementation. Read all open PR claims
  at task start, after long tool calls, before edits, and before each push.
- Keep the PR watchdog active. Read new PRs and updates as soon as notified.
  Stop overlapping work until the owners agree on separate scopes.
- One owner controls each task and file scope. Use a separate branch and worktree.
  Do not change another worker's files, evidence, processes, or analysis sessions.
- Use the PR for shared progress, questions, evidence, blockers, and handoff.
  Local agent messages do not replace the GitHub record. Confirm receipt separately
  from approval. Do not publish private reasoning or credentials.
- Use Standard/default mode. Fast and Ultrafast modes are prohibited. Use High
  reasoning for assigned Sol, Luna, and Astra agents.
- Sol 6.1 or Luna authors application Rust. An independent Sol High reviewer
  checks each code change. Astra High verifies each milestone. Root coordinates
  and integrates. Keep authorship and review separate.
- Recommend RAE with Ghidra for reverse engineering. Verify actual tool access.
  Reuse evidence and matching sessions before a new import. Read docs/RESEARCH.md.
- Support each behavior claim with the build, SHA-256, artifact, address or
  reproduction steps, evidence ID when available, and limits.
- Keep static facts, observed behavior, inference, design choices, and unknowns
  separate. Compilation and synthetic tests do not prove vendor parity.
- Mark a feature complete only after implementation, meaningful validation,
  independent review, Astra verification, and a reproducible Windows comparison.
- Use ASD-STE100 Simplified Technical English for all new English text. Apply this
  rule to chat, agent messages, documentation, PRs, issues, code comments, and
  commit messages. Use the writing rules and dictionary in the
  [official standard](https://www.asd-ste100.org/).
- Use short, complete sentences and active voice. Put one instruction in each
  sentence. Use the same technical term for the same item. Do not use em dashes.
- Preserve exact evidence, source strings, code, paths, hashes, and addresses.
  Do not rewrite reviewed records or translate original reference text.

## Current source base

- At task start and resume, fetch the target repository remote main. Record its
  full SHA and the check time. A cached origin/main alone is not a fresh check.
  If remote access fails, report that the newest base is unverified.
- Before source edits, validation, and each push, check remote main again. Check
  after a base-change notice or a long tool call before more source work.
- Start new source branches from the verified remote main. For an existing task,
  verify that the latest main is an ancestor of the task HEAD. If main has moved,
  checkpoint your own work before updating your own branch or a new worktree.
  Preserve existing commits and uncommitted files. Do not reset, overwrite, or
  update another worker's worktree. Do not force-push reviewed history.
- Report the repository, worktree, branch, HEAD, verified main SHA, ancestry result,
  and clean or dirty status in comms and the task PR. Read the current instructions
  and open PR claims before continuing. A worker registration is not verification.
- Analysis that compares native source must record the exact current source HEAD
  and file hashes. Keep vendor binaries, fixtures, and saved evidence at their
  declared build and hash. Do not change those pins to match a source merge.
- Reviewers inspect the exact candidate commit. Record its relationship to current
  main. If an update changes the candidate, obtain review for the new exact commit.
  Repeat affected validation before publication. Report unresolved base conflicts.
- Keep completed worktrees and reviewed records unchanged as historical evidence.
  Mark them inactive. Before reuse, create or update an owned task worktree from
  the verified current base. Root must check actual active workers after merges.
