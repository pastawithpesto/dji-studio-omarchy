# Verify automatic PR watchdog execution

Owner: @pastawithpesto

Claim: `.github/workflows/pr-watchdog.yml` and this task file.

Automatic execution of the existing read-only `pull_request_target` workflow is
verified. [Run38194148483](https://github.com/pastawithpesto/dji-studio-omarchy/actions/runs/38194148483)
completed successfully on2026-10-12 for PR28 head
`0813f8e3ec1c6126c2f46c57a2e8bdd2ee01b607`.
The earlier unverified status and proposed switch to `pull_request` are superseded.
The correction restores the current main workflow unchanged. It preserves the
read-only permissions, no-checkout design and existing scope parser.
This PR now delivers the verification record only. It changes no workflow behavior.

Historical proposals and failed or unobserved event attempts remain in prior commits.
A successful run is a snapshot of the claims read by that run, not a file lock or
a guarantee of future API access. Read current open claims and current checks
before edits. Independent Sol High review and Astra High verification of the
corrected exact candidate remain required before the protected merge.
