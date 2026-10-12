# Original GUI in Rust and QML

The user requires Rust and QML application source. Keep original DJI text,
layout, names, resources and interactions. Preserve the recovered QML bytes.
Do not add C++ application code or invent replacement screens and controllers.

This task replaces the earlier C++ adapter direction. Historical C++ work and
its test records remain evidence. They do not make the current GUI compliant.
The custom C++ host, simplified screen, and their build/tests have been removed
from the current source. Their exact files and historical records remain
preserved. The original resource bundle and frozen provenance records are unchanged.

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

## Rust Qt and QML integration

`gui/rust/qt` registers the exact original WindowPositionDetector module and type
at version 1.0. It preserves isWindowCompletelyOnScreen and
resetWindowToBestScreen with their original QWindow argument boundary. Native
screen enumeration retains list order and null entries. Autocxx generates
pointer/list aliases from installed Qt headers. CXX-Qt-Lib supplies the native
list storage and operations. No handwritten C++ or guessed container layout is used.

`gui/rust/host` creates the Qt application and engine from Rust. It compiles the
unchanged original resource collection and loads `qrc:/qml/Main.qml`. The native
type registration runs before engine creation. Missing services cause actual Qt
errors. The host adds no replacement screen, placeholder controller or media UI.

The adapter checks cover native list storage, eight ordered-call cases, and a
QML test with null arguments and a real test-owned window. The host checks cover
an original resource, the original Config import, load failure and event-loop
exit. Local checks use Qt 6.11.2. Hosted Qt API checks use the Ubuntu distribution
version. Neither version establishes Windows or full original GUI parity.

## Remaining work

The combined host reports nine missing original native modules. Recover their
contracts and implement the supported behavior in Rust. Further missing types,
context objects and startup actions can appear after those modules exist.
Native object lifetime and GUI-thread requirements remain binding preconditions.
Windows DPI, Wayland movement, media linkage, project behavior and reference UI
comparison remain unverified. Preserve failed runs. Obtain independent source
review and separate milestone verification before any merge.

Passing policy and Qt boundary checks do not prove successful original Main
startup or complete application behavior.
Active disjoint implementation PRs and the serial merge queue retain ownership.
