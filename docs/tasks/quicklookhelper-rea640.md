# QuickLookHelper.dll reverse engineering

Original distribution: DJI Studio 1.0.0.30839.
Original file: QuickLookHelper.dll, 128696 bytes.
SHA-256: c49e03bee7bfed1a1b9d6c982afdce43bb32c8dfe023ee29b55865243e59255b.

The existing coverage record contains inventory only. No matching behavior packet was found in the declared report and snapshot search. Preserve all earlier research.

## Scope

This PR owns this task plan and the selected additive R9 correction in docs/evidence/quicklookhelper-r9-correction/**. Local evidence belongs to reconstruction/quicklookhelper-rea640-20261011. Reserve a separate file claim before application changes.

Use REA 6.4.0 with Ghidra 12.1.4. Root owns one isolated analysis session. Reuse its outputs. Do not duplicate the import or change another DLL session.

Account for both exported APIs, all detected internal procedures, thunks, imports, data, strings and unresolved code ranges. Record each decompilation result and its limitations. Check behavior against original bytes and disassembly. Procedure counts are not behavioral completeness.

Divide analysis between factory and lifetime contracts, internal virtual methods, and caller bindings. Keep author scopes separate. Obtain independent exact-packet review and milestone verification.

## Completion check

Each export and detected procedure has an exact address and a recorded disposition. Supported contracts include original names, inputs, outputs, branches, external dependencies and source evidence. Preserve failures and unresolved boundaries. A decompiler output alone is not a working port.

Vendor execution, full runtime behavior, Linux adaptation, application integration and Windows UI comparison are separate gates. No merge or release is requested.

## Source base

Repository: https://github.com/pastawithpesto/dji-studio-omarchy.git.
Worktree: source-worktrees/root-quicklookhelper-plan-20261011.
Branch: work/quicklookhelper-rea640-20261011.
Fresh main and initial HEAD: 91f1fd620a7a0aea74db49a03be240ee59681401.
The initial worktree is clean. Preserve the canonical AGENTS.md and AUTHORS.md changes.

## Selected initial-erratum R9 correction

The [new correction report](../evidence/quicklookhelper-r9-correction/REPORT.md) replaces only the overly broad initial R9 statement. It preserves the frozen original report and findings. Body0x1800025b0 reads R9 after writing its own constant. No direct read of the incoming forwarded byte is established before replacement in the recorded paths. Fourth argument meaning and transitive callee behavior remain unresolved.

The [manifest](../evidence/quicklookhelper-r9-correction/MANIFEST.json) seals the report, findings, original pins, byte witnesses, saved assembly and bounded checks. All17 code spans and3 data spans match the pinned DLL. All50 erratum and70 erratum-review entries match. The six approved initial corrections, separate C1/C2 and H1 approvals, original failed probe,47-decision accounting,335 unresolved records and3 historical instruction mismatches stay preserved. This is a selected correction. It does not complete the whole research task.

Root instruction3243 assigns the correction to the separate author21 job, routing identity sol-3. Runtime: GPT-6.1 Sol, High, Standard/default, Fast=false. Original author labels remain unchanged. Independent exact-head source review and separate milestone verification are pending. No vendor execution, new import, application change, parity approval, merge or release occurs.

The [source record](../evidence/quicklookhelper-r9-correction/SOURCE-BASE.json) pins the new owned branch and appended main. The exact published candidate and review handoff are recorded in reconstruction/root-sol-pr25-pr21-20261012/author21/HANDOFF.json and HEAD.json. Historical source identities above remain unchanged.
