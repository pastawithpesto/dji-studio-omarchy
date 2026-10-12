# Reusable work instructions

The user requests work instructions without model or staffing rules.
Keep current source checks, ownership, comms, PR reservations, evidence,
validation and independent review rules.
Keep scheduling and model assignment in coordinator configuration.
Preserve historical reports, launch records and attribution.

This PR owns AGENTS.md, AUTHORS.md and this task plan.
PR3 retains CONTRIBUTING.md and other shared documentation.
The local coordinator configuration replaces the pending milestone reviewer
with GPT-6.1 Sol High. That configuration is outside this source repository.
The PR changes instructions only. It does not change application behavior.

Validation checks that the worker instructions contain no model names,
subscription assumptions, staffing count or scheduling directives.
The local bus routing and launch policy receive separate functional checks.

## Review correction

The review found that the change removed the ASD-STE100 writing rule.
The correction restores that rule from the prior instructions.
Model and staffing rules remain in coordinator configuration.
The branch includes current main366dd125c928ea3bf1c813d6f6b42abc1242e13d.
Independent source review and milestone verification must inspect the corrected
exact candidate before merge.
