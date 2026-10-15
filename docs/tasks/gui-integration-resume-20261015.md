# Integrate the three accepted GUI modules

Owner: @pastawithpesto. Root coordinates the source transfer and final integration.
The resume assessor is sol-ui-reviewer. The assessor has not authored the module
source and does not approve a future integration candidate.

Reserve the exact 157 changed paths from local accepted candidate
`8b70e1ef4e8074cef7c06ec6a17ace0dd506fb69`, plus this task plan.
The PR claim lists each path. It covers FpsDetect, UserGuideTypeModel, BusinessLog,
the four host files, accepted evidence, accepted task records, and docs/STATUS.md.

## Existing work

The accepted candidate is based on main
`d922d46337150db102cef675073cfa392ef92bbc`. Main is its ancestor.
The 2026-10-15 resume check verified all 157 source hashes and all 40 evidence
record hashes. No current PR claim overlaps these paths.

The immutable manifest SHA-256 is
`2811325bfc0a35e35e7519557a8ce31c3e088b8b49afc00da7385dda7fc91ef8`.
The separate final review SHA-256 is
`1a339fa24501a4574d4d209b15068696606fb97792d4490c79a9ff653078270f`.
The review is recorded in bus 4276. The original handoff and review remain local.

## Plan

1. Open this plan-only draft PR and obtain a successful current PR watchdog run.
2. Root transfers the accepted 157 files without changes into this owned branch.
3. Verify each transferred blob against the accepted source pins. Check the
   original resource trees, all 1,826 aliases, and all 410 QML aliases.
4. Reuse the recorded bounded tests for unchanged application and compiler bytes.
   Run only checks required for the new candidate or an affected change.
5. Obtain independent review of the exact new candidate. Obtain separate
   milestone verification. Root controls any final merge.

## Completion check and limits

The source transfer must match every accepted source pin. The original QML,
strings, and resource aliases must remain unchanged. Keep application source in
Rust and original QML. Qt dependencies and generated binding code use C++.
The reviewed Rust generator derivative emits binding C++; it is a disclosed
build dependency. Generated C++ is not tracked application source.

The combined local host check passed for the three modules. Original Main still
fails at six top-level native imports. Later nested types and context failures
remain unmeasured. Full GUI, graphics, QObject ABI, Windows, camera, processing,
and project parity remain incomplete.

Do not repeat extraction, research, or native tests without an affected change.
Do not add fake controllers. Do not execute vendor code, add imports, change
global settings, or change peer processes. Preserve all sealed records and the
old author and canonical worktrees.
