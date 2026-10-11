# Agent instructions

Read README.md, CONTRIBUTING.md, docs/STATUS.md, and docs/RESEARCH.md first.

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
- Use concise technical English. Do not use em dashes. Keep original evidence exact.
