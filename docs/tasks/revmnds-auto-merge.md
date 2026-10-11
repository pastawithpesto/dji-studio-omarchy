# Automatic acceptance for revmnds

Owner: @pastawithpesto

Reserve `tools/pr_acceptance/**`, `.github/workflows/revmnds-auto-merge.yml`,
and this task file. Do not edit the existing watchdog workflow claimed by PR 2.

Implement automatic merging of eligible PRs authored by `revmnds`, numeric GitHub
user ID 278795669. Verify current write access. Limit the target to this repository
and `main`. Skip drafts and unrelated authors.

Retain the existing Sol High review and Astra High milestone requirements. Root
records their completion as an approving GitHub review on the exact PR head.
The automation requires that current-head approval from repository owner
`pastawithpesto`, numeric ID 23729105. Never manufacture a review or approve code
solely because the author is trusted.

Before each merge, verify current full PR scope claims, no overlap or unclaimed
files, mergeability, checks and review state. Fail closed on incomplete or failed
API results. Merge with the expected head SHA. Never check out or execute PR code.
Use a bounded read-only dry run for initial validation. Keep mutation explicit.

Provide meaningful independent fixtures for eligible and ineligible cases,
changed-head races, drafts, author identity, approval identity, conflicts, failed
checks and API failures. Obtain independent Sol review and Astra verification
before enabling the worker. Document service lifetime and polling limits.

A periodic hosted workflow or local worker may perform the check. Do not claim
hosted automatic operation until a real scheduled or PR event run is verified.
No application source or frozen README change is part of this task.
