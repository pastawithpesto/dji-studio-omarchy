# Three local DJI GUI modules

The user assigns three GPT-6.1 Sol High agents one missing module each.
Keep this work local. Do not push, open a PR, merge remote source, or publish a release.
Preserve the canonical dirty source tree, original QML, resources and peer sessions.

## Assigned parts

- sol-1: FpsDetect, including the original frame timer and signal behavior.
- sol-2: UserGuideTypeModel, including UserGuideType and MoueseEventType.
- sol-3: BusinessLog, including the two original enum tables and creation policy.

Each author owns a separate new Rust crate and its evidence and tests.
Root owns host dependency and registration integration in this local branch.
The source base is main 7a5d360342267cce0d05670a413c893407ec8d04.
Current open claims have no overlapping GUI implementation scope.
The addressed project bus records local ownership and resource grants.

Main d922d46337150db102cef675073cfa392ef92bbc was checked and merged locally.
It changes attribution records. It does not change the GUI or application code.
Root owns the host Cargo manifests and lock, native registration in main.rs,
the existing host qt_runtime test, this plan, and docs/evidence/gui-three-sol.
The host test will load all three modules in one engine. It will also keep the
existing original resource and lifecycle checks.
Root also owns the local startup status update in docs/STATUS.md. Bus4267 records
this scope addition before edits. No current open claim overlaps this path.

## Method

Reuse original QML and pinned saved evidence before new analysis.
Check original file SHA, registration records, metaobjects and behavior bytes.
Close a bounded contract with independent peer review before acceptance.
Do not use invented enum values, fixed fake properties, or no-op success methods.
Application code is Rust. Qt generates required external binding code.
All full binary evidence, private records and build outputs stay outside source.

Use one serialized native build and test family, one Cargo job, and owned targets.
No new Ghidra import is authorized without a separate precise grant.
Pure Rust, Qt metadata and original-name QML checks must test supported behavior.
Review each exact module candidate and then the combined host candidate.
Keep original resource tree identity unchanged.

## Completion check

Each supported module API and recovered behavior has passing reference checks.
Original module names, version, type names, enum values and registration kind match.
Frame timing arithmetic, signal order and Qt hooks match the supported FpsDetect contract.
Original guide enum scope must be verified, not inferred from passing value lookup.
BusinessLog must reject construction with its original reason.
The combined host reports the three resolved imports and every remaining Main failure.
Static facts, native Qt checks, Windows comparison and whole GUI parity stay separate.

## Local result

The combined host loads all three modules in one engine. Its original resource
and lifecycle checks pass. The exact original Main still fails on six top-level
native imports. The three imports in this task resolve. Later nested types and
context services remain unmeasured after the import failure.

See [the local report](../evidence/gui-three-sol/README.md) for candidate commits,
review decisions, reference checks and Qt-version limits. Original QML, resource
trees and QRC bytes remain unchanged. The work stays in the owned local branch.
No source was pushed, merged remotely or published.
