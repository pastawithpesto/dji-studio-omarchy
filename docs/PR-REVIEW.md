# PR review and required GitHub status

The PR owner must arrange independent review and deliver the evidence to root.
Uploading a PR does not give its author authority to approve their own work.
Review comments, GitHub approval, and a commit status are separate records.

## Roles

| Role | Responsibility |
| --- | --- |
| PR owner or uploader | Request reviews, correct defects, and send the exact candidate and evidence to root. |
| Independent Sol High reviewer | Inspect the exact change and relevant evidence. Record a verdict, findings, validation, and limits. Do not review a change that you authored. |
| Astra High verifier | Verify the declared milestone on the same candidate. Check the independent review, validation, and remaining limits. |
| Root coordinator | Check the completed gates and current repository state. Record the required GitHub approval and commit status under the permitted account. |

Separate agents can publish their evidence through the same GitHub account.
Record each agent's identity, role, model, and reviewed commit in its report.
A shared account does not make an author's self-review independent.
GitHub also does not permit a PR author to approve their own PR.

## Required handoff

1. Read the current instructions and all open PR claims.
2. Fetch current main and verify its relationship to the candidate.
3. Record the full candidate SHA and relevant validation links.
4. Request an independent Sol High review of that exact candidate.
5. Correct blocking findings and obtain review of the new candidate.
6. Obtain Astra High verification of the declared milestone.
7. Send root the candidate SHA, both verdicts, evidence links, check results, and limits.
8. Keep the PR in draft until the required review and verification finish.
9. Root must recheck the head, main, claims, checks, and unresolved review findings before attestation.

Use the addressed project bus when it is available.
Keep the evidence and handoff in the PR as the shared record.
If a required reviewer or the coordinator is unavailable, record that blocker.
Automatic merge and the acceptance worker do not start agent reviews.

## GitHub records for revmnds PRs

Current main protection requires `agent-review/verified`.
The [acceptance worker policy](../tools/pr_acceptance/README.md) adds identity checks.
For a PR authored by `revmnds` (ID `278795669`), root must use the repository owner
account `pastawithpesto` (ID `23729105`) to create both records below:

- An `APPROVED` PR review on the exact head commit.
- A successful **commit status** with context `agent-review/verified` on that head.

The approval body must identify the exact candidate and link both agent verdicts.
The status `target_url` must link the review evidence.
The status attests that the agent gates finished. It is not a hosted CI result.
A comment that says PASS or APPROVED does not create either record.
A check run with the same name does not replace the commit status for the worker.
The uploader `revmnds` supplies the evidence but cannot replace the owner attestation.

These owner identity rules describe the current revmnds acceptance worker.
That worker skips other PR authors. Do not use it to approve an owner-authored PR.
Root must arrange the permitted GitHub reviewer for such a PR.
Do not alter branch protection or fabricate a successful status to clear a blocker.

## Record and verify the attestation

Only root may perform this step after the actual gates above pass.
Use the existing authenticated GitHub interface. Keep credentials out of records.
Verify the authenticated login and numeric ID before making either request.
Use the explicitly reviewed SHA, not a newly selected head without review.

The GitHub REST requests are:

```text
POST /repos/pastawithpesto/dji-studio-omarchy/pulls/PR_NUMBER/reviews
{"commit_id":"REVIEWED_HEAD_SHA","event":"APPROVE","body":"Exact candidate, independent Sol review link, Astra verification link, validation, and limits."}

POST /repos/pastawithpesto/dji-studio-omarchy/statuses/REVIEWED_HEAD_SHA
{"state":"success","context":"agent-review/verified","target_url":"OWNER_REVIEW_OR_EVIDENCE_URL","description":"Independent review and milestone verification passed"}
```

Verify the returned review state, commit ID, author login, and numeric ID.
Verify the returned status context, state, creator identity, and evidence URL.
Read the PR head again and confirm it still equals the reviewed SHA.
If the head changes, review the new candidate and repeat affected validation.
The old review and status must not be presented as approval of the new head.
Resolve active changes-requested reviews before acceptance.
Verify all relevant checks on the head and current test-merge commit.
Report missing or pending checks as blockers, even if another run passed.

Posting the successful status can allow an already enabled automatic merge.
Observe the resulting PR state and exact merge commit before reporting a merge.
Do not treat a polling heartbeat or an enabled automatic merge as a completed merge.

## Scope of approval

State the bounded result that the evidence supports.
A CI milestone can pass while Windows comparison and application parity remain open.
Compilation and synthetic media do not establish camera, GUI, or vendor parity.
Use the feature completion rules in [AGENTS.md](../AGENTS.md).

API references: [create a PR review](https://docs.github.com/en/rest/pulls/reviews#create-a-review-for-a-pull-request)
and [create a commit status](https://docs.github.com/en/rest/commits/statuses#create-a-commit-status).
