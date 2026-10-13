# Resumable REA analysis queue

Build an explicit research tool for bounded DJI Studio native analysis.
Use a JSON manifest with source hashes, tool identities and function targets.
Reuse matching saved evidence before new analysis.
Keep raw results, failed attempts and provenance.
Resume only after source and result checks pass.
Report collected evidence separately from behavior review and application parity.

## Scope

- tools/rea_analysis_queue.py
- tests/test_rea_analysis_queue.py
- docs/REA-ANALYSIS-QUEUE.md
- docs/tasks/rea-analysis-queue.md
- docs/evidence/rea-analysis-queue/**

Root coordinates the work and validates a local reference packet.
GPT-6.1 Sol High authors the tool.
A separate GPT-6.1 Sol High session reviews the exact candidate.
The user requested both model assignments.

## Validation

Verify the current REA command and result schema before implementation.
Test interruption, failed attempts, corrupt results and changed source identities.
Test timeout cleanup and coverage reporting.
Run a bounded integration with pinned original artifacts and saved evidence.
Keep private binaries and full native analysis data outside the public repository.
Obtain independent code review and verify the reviewed milestone.

## Limits

This tool does not implement DJI application behavior.
It does not execute vendor DLLs.
It does not prove Windows or camera parity.
Session reuse and batching remain optional experiments under docs/REA-WORKFLOW.md.
No speed improvement or default optimization adoption is claimed.
Keep the PR in draft until the required gates pass.

## Candidate result

The author candidate implements saved-evidence collection and explicit live REA
function queries. It seals each attempt and checks original inputs before resume.
It retains failed attempts, raw output and source-independent historical reports.
Linux process cleanup covers owned detached descendants.

Root repeated all 29 control tests. They pass.
The saved original-DLL integration and resume pass.
The current matching-profile CLI snapshot adapter and resume pass.
The public integration packet is in docs/evidence/rea-analysis-queue/.
Independent exact-candidate review and hosted final-head checks remain separate.
