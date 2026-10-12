# Original GUI in Rust and QML

The user requires Rust and QML application source. Keep original DJI text,
layout, names, resources and interactions. Preserve the recovered QML bytes.
Do not add C++ application code or invent replacement screens and controllers.

This task replaces the earlier C++ adapter direction. Historical C++ work and
its test records remain evidence. They do not make the current GUI compliant.
The existing experimental GUI is still a migration target.

## Current Rust implementation

`gui/rust` implements the recovered integer geometry policy used by the original
WindowPositionDetector. Its crate name `window-position-detector` is a Rust
identifier adaptation of that original type name, not new product text.
The Rust value types and getter trait are independent safe interfaces.
They do not claim the original QObject or QWindow pointer ABI.

The policy preserves wrapped DWORD endpoints, the original null rectangle rule,
containment, intersection, signed score selection, first positive ties, lazy
primary-screen selection and the exact reset getter sequence. Twenty-seven
literal contract cases cover integer limits, reversed endpoints, zero extents,
null equality, negative scores, oversized windows and changing getter values.

Use the independently approved method and Qt geometry records listed in
`gui/docs/window-position-contract.md`. Do not repeat extraction or import a
binary without a resource grant. Original binary behavior and native Qt
integration remain separate obligations.

## Remaining integration

Register the exact original WindowPositionDetector module and type at version
1.0 from Rust. Preserve the names isWindowCompletelyOnScreen and
resetWindowToBestScreen and their original QWindow argument boundary.
Use original QML entry points and resource aliases. Replace the C++ host and
independently authored experimental screen as their original interfaces become
supported. Missing services must remain unresolved instead of success stubs.

Validate the actual Rust/QML boundary on a new test-owned window. Verify thread,
object lifetime, screen-list order, null entries and lazy fallback. Native Qt
platform APIs are an integration boundary; Windows DPI and Wayland movement
remain unverified. Preserve failed runs. Obtain independent source review and
separate milestone verification before any merge.

The pure policy crate has no GUI startup or media parity claim. Do not use its
passing tests as proof that original Main.qml or the complete application works.
Active disjoint implementation PRs and the serial merge queue retain ownership.
