# REA benchmark policy

Owner: @pastawithpesto. Author: root.

The user requests repository instructions for faster REA work. Test each proposed
optimization before adopting it. Discard instructions that produce bad results.

## Scope and plan

Own only `docs/REA-WORKFLOW.md` and this task plan. PR11 owns `AGENTS.md`.
PR3 owns `docs/RESEARCH.md`. Ask their owners to add the workflow link separately.
Preserve their pending source and latest upstream REA instructions.

Write the workflow and a mandatory benchmark gate. Compare equivalent tasks on
at least three small DLLs. Separate new decompilation from saved evidence
inspection. Require repeated measurements and unchanged evidence checks.
Reject regressions, missing evidence, failures and unsupported speed claims.
Retain historical reports when removing a failed optimization from active rules.

## Existing evidence

The local small DLL benchmark used REA 6.4.0 and Ghidra 12.1.4. Saved dossier
inspection took 7.7 to 9.9 times less wall time than fresh analysis. It used one
fresh run and two reuse runs per DLL on an uncontrolled host. This motivates a
candidate workflow. It does not satisfy the stronger adoption gate or establish
performance with current upstream REA. Original binaries and full local evidence
are not part of this documentation upload.

## Completion check

Inspect the instructions and links. Confirm that the gate defines baseline,
candidate, source pins, equivalent scope, repeated runs, correctness, acceptance,
rejection, rollback and revalidation after tool changes. Request independent
review of the exact documentation commit. Do not claim a new benchmark ran.

Keep the PR in draft until the required review is complete. No application code,
vendor execution, merge or release is part of this task.
