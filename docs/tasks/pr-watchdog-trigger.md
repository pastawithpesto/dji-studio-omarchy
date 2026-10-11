# Verify automatic PR watchdog execution

Owner: @pastawithpesto

Claim: `.github/workflows/pr-watchdog.yml` and this task file.

The hosted manual watchdog run passed. PR target events have not produced a run.
Use standard PR events for this read-only check. Keep the current scope validation,
read-only token, and no-checkout design. Verify an automatic hosted run before merge.
Obtain independent Sol High review and Astra High milestone verification.
