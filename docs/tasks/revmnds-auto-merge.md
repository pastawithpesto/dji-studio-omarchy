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

## Author implementation

The local Python worker and policy fixtures are in tools/pr_acceptance. It defaults
to dry-run; root activation requires explicit --apply after independent Sol source
review and Astra verification. No hosted workflow is added. The existing read-only
watchdog is unchanged. The worker saves merge intent, rereads current gates and
uses an expected-head SHA merge without executing PR code.

The protected-policy followup supersedes the historical unprotected candidate
bd64a431, which remains preserved and must not be activated. Require the exact
root1427 normalized main protection GET, strict named status, admin enforcement,
no force pushes or deletion, no repository/inherited rulesets and no active rules. Unknown, missing, stronger or
weaker policies refuse. Require the owner-created agent-review/verified success
commit status on the current head in addition to the owner approval. Root records
it only after actual independent reviews, validation and current full claims.
All other returned checks/statuses on the head and test-merge commit must pass.
Verify head ancestry contains current main and mergeability is clean. Reread and
compare policy and gate identities before the expected-head merge.
See tools/pr_acceptance/README.md for the exact policy, polling bounds,
reconciliation, reproduction and remaining nontransactional race window.

Authored source and mocked tests are not independent approval or a real merge.
Keep PR4 in draft until both review gates pass. Root handles upload and activation.
When hosted events are unavailable, root can record an accurately named
agent-review/verified success status on the current head after actual reviews
and validation, linking their evidence. This is an agent-gate attestation, not
hosted CI. The worker never creates it or spawns reviewers on its own.
