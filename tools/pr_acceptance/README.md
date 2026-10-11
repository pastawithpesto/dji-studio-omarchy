# Local PR acceptance worker

This is independent operational Python design, not DJI behavior. The reserved
plan is docs/tasks/revmnds-auto-merge.md. The existing read-only watchdog remains
separate and unchanged. No hosted workflow is added. Local polling avoids relying
on the unverified hosted PR trigger.

Default mode is dry-run. No approval is created by this worker. Root may enable
`--apply` after independent Sol source review and Astra milestone verification.
The user has authorized automatic acceptance without a separate confirmation for
each PR, once all the gates below pass.

## Policy

The repository is fixed to pastawithpesto/dji-studio-omarchy and the target is main.
The author must be revmnds, numeric ID278795669, with current write/admin permission
and push=true. Drafts and other authors are skipped. The latest active substantive
owner review must be APPROVED on the exact head commit and come from
pastawithpesto, numeric ID23729105. Root submits that review only after independent
Sol and Astra gates passed. GitHub review text or contributor identity alone does
not prove those reviews happened; the owner approval is the explicit attestation.

Each reviewer's latest active APPROVED or CHANGES_REQUESTED review is selected by
submission timestamp and review ID. COMMENTED does not erase a veto. DISMISSED
records do not count as active approvals or vetoes and cannot erase another active
veto. Outstanding CHANGES_REQUESTED from any reviewer blocks, even on an older
commit. Pending reviews, unknown states and missing fields fail closed. A new
head invalidates owner approval. The worker never approves its own candidate.

Every cycle reads all open claims, including drafts and other authors, and the
complete changed-file API inventory for each. Count/duplicate/pagination gaps,
rename origin omissions, uncovered files and overlapping claims stop evaluation.
The copied claims.py is pinned to SHA256
a82816161fa1ae5afe92de9a8302ee394ee9d36105aa9b0454308a3f8b773f30,
the previously reviewed f374e9c checker. API patches and PR strings are data.
No branch is checked out and no PR code is executed.

Mergeability must be true with mergeable_state=clean. All returned latest status
contexts and check runs on the current head and current test-merge commit must
succeed. At least one status/check must exist on the head itself. Pending,
neutral, skipped, cancelled or ambiguous duplicate latest checks block. This
strict policy can delay PRs whose checks run only on the test-merge commit.

Hosted PR events are still unverified. After the actual independent Sol source
review, Astra verification and relevant validation pass, root records two GitHub
attestations on the current head: the owner APPROVED review and a success commit
status named `agent-review/verified`, linking the review evidence. That status
attests completed agent gates; it must not be described as a hosted CI run. The
worker can accept this successful head status, while still requiring every other
returned status/check to succeed. It never creates reviews or commit statuses.
Periodic polling does not start agent reviews. Root coordinates those through
the addressed comms bus, then records the actual completed gates on GitHub.

This initial version supports an unprotected main branch with no active branch
rules only. Protected branches and any active ruleset are refused. This avoids
using an owner's permissions to bypass a rule the worker cannot independently
validate. A future policy adapter needs separate review. The read-only live
observation during authorship confirmed protected=false and no active rules;
these conditions are rechecked, not assumed indefinitely.

An unmet complete gate skips that candidate and permits another candidate to be
examined. API/schema/completeness failures stop the cycle. The complete claims
snapshot and permission/review/check identities are read twice and compared.
A final PR detail read precedes a REST PUT merge with the expected head SHA and
merge_method=merge. At most one PR merges per cycle. There is no admin or bypass
option. Repository merge commits must be enabled.

GitHub's expected SHA condition guards head changes at merge time. It does not
atomically lock base, review, permission, check or claim state. A change after the
last corresponding GET remains a race window. API eventual consistency also
limits snapshots. The worker rechecks aggressively but does not claim a
transactional merge gate. Owner attestation and the independent review process
remain necessary.

## Reproduction and activation

Python standard library and the existing authenticated gh binary are required.
The pinned local gh path is recorded in worker.py. Credentials stay in gh's
normal environment/configuration; never put tokens in argv or saved reports.
The transport strips GH_DEBUG and never records stderr or request headers.

From the repository root:

```sh
python3 -B tools/pr_acceptance/test_worker.py
python3 -B tools/pr_acceptance/worker.py --once --runtime /absolute/path/to/new-acceptance-dry-run
```

The tests use fixed independent expected outcomes, mocked transport and mocked
merge receipts. No tests mutate GitHub or start a service. They include stale
approval, identity spoofing, current veto, check/claim/file gaps, pagination,
API errors, race windows, explicit mutation flags, persisted retry and uncertain
merge reconciliation. A passing mocked merge is not a real merge proof.

After both reviews, root may start a dedicated transient user service with an
absolute reviewed source path. For the assigned author worktree:

```sh
/usr/bin/python3 -B /home/violence/Projects/dji-studio-omarchy/source-worktrees/revmnds-auto-merge/tools/pr_acceptance/worker.py --runtime /home/violence/.local/state/dji-revmnds-acceptance
```

That command is continuous dry-run. Add `--apply` only for the reviewed root
activation. `--once --apply` also permits one real merge and is not a safe dry-run.
No service is installed or started by this author handoff. Use a fresh dedicated
runtime, never a watchdog or peer evidence directory. The lock is per runtime.
Only one apply worker should be active for this repository.

Verify the actual process argv, PID and /proc start ticks against heartbeat.json,
the reviewed code hash, and two fresh increasing attempts. Check mode=continuous,
the intended apply value, error=null and current last_success_utc. A no-candidate
result is a healthy observation, not a merge. Confirm a real merge using the PR's
current API state and exact merge commit, not a heartbeat alone.

Healthy cycles wait at least30 seconds after completion. Each cycle permits at
most128 requests, at most180 seconds before starting a request, and25 seconds per
request. One in-flight request can extend that bound to205 seconds. Open PR lists
use at most5 pages, file inventories30, reviews/status/checks10, rules5, all with
100 records per page. A terminal short page is required; exact-limit full pages
are refused. Thus 3,000-file PRs cannot pass. Retry grows30/60/120/240/480/900
seconds plus jitter, with Retry-After/reset as a lower bound. Next-attempt time
and failure count persist. Continuous restart respects the cooldown; --once
runs immediately.

Before a PUT, an atomic durable merge intent is saved. A confirmed rejection
(403/404/405/409/422 on that PUT) clears it. Timeout, malformed success, uncertain
receipt or crash retains it. Later cycles only reconcile that PR: a closed,
merged PR with the same head clears the intent and records the result. An open
PR or inaccessible reconciliation requires operator attention and blocks more
merges. A GET403 does not clear a prior uncertain intent. Root can inspect the
saved intent and remote PR, stop its own acceptance service, preserve the old
runtime, and start a fresh dedicated runtime after resolving the uncertainty.
No unattended blind reissue of an uncertain PUT occurs.

Runtime state and heartbeat are atomic file replacements with file fsync.
Parent-directory power-loss durability is not promised. Filesystem failures can
stop the worker. events.jsonl retains poll decisions and confirmed/reconciled
merge results; there is no automatic disk cleanup or bus notification outbox.
The existing read-only watcher continues to supply claim notifications.

## Primary API references

- [Expected-SHA merge endpoint](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request)
- [Chronological review inventory](https://docs.github.com/en/rest/pulls/reviews#list-reviews-for-a-pull-request)
- [Latest check runs](https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference)
- [Combined commit status](https://docs.github.com/en/rest/commits/statuses#get-the-combined-status-for-a-specific-reference)
- [Current collaborator permission](https://docs.github.com/en/rest/collaborators/collaborators#get-repository-permissions-for-a-user)
- [Branch identity/protection](https://docs.github.com/en/rest/branches/branches#get-a-branch)
- [Active branch rules](https://docs.github.com/en/rest/repos/rules#get-rules-for-a-branch)

These API contracts support transport design, not DJI behavior or Windows parity.
