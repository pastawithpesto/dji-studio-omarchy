# BusinessLog 1.0

Owner: sol-3. The local instruction4065 reserves this scope. The user requests
local work. It overrides the PR reservation procedure for this task.

Owned paths: `gui/rust/business-log/**`, this file, and
`docs/evidence/gui-business-log/**`. Root owns host integration. Preserve the
original QML and resources. BusinessLogger is a separate module.

The source base is main `7a5d360342267cce0d05670a413c893407ec8d04`.
The worktree is `/home/violence/Work/dji-gui-three-sol-20261013/business-log`.
The branch is `local/gui-business-log-20261013`. The initial tree is clean.
A fresh fetch on 2026-10-13 confirmed the same main and HEAD. Main is an ancestor.
The current open claims do not overlap the owned paths.

## Plan

1. Audit every original QML reference.
2. Check saved registration evidence against the pinned EXE bytes.
3. Recover all enum names, values, widths, and scope flags.
4. Obtain independent review of the bounded contract.
5. Implement the exact enum module in Rust with generated Qt bindings.
6. Test all original enum entries and the creation rejection through QML.
7. Run source checks. Commit locally. Request independent candidate review.

## Static contract

The pinned reference is DJI Studio 1.0.0.30839. The EXE SHA-256 is
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
The registration call at `0x14068b1e7` registers an uncreatable metaobject at
`0x1430cc950`. Its URI and type name are `BusinessLog`. Its version is1.0.
Its creation error is `enums only`.

The metadata at `0x1430ccc80` has two scoped enums, `Stream` and `Events`.
It has no methods, properties, constructors, or class information.
Both enums use signed32 values. Both `UNKNOWN` entries equal -1. The value0
has no named entry. The 28 other values are in the selected evidence record.
`Main.qml:21` imports the module. Line693 reads `Stream.APP_LAUNCH` and
`Events.LOAD_EDITOR_QML`. These values are1 and11.

CXX-Qt0.10.0 rejects explicit enum values. The proposed adapter uses generated
bindings to Qt's `QMetaObjectBuilder` to retain the exact values and error text.
Qt private headers are an explicit build dependency. Application behavior remains
in Rust. No handwritten C++ source or inline C++ payload is permitted.

Full raw evidence stays outside source at
`/home/violence/Projects/dji-studio-omarchy/reconstruction/root-gui-three-sol-20261013/business-log`.
Offline evidence inspection is separate from new REA analysis and vendor execution.
Full Main startup, BusinessLogger effects, and Windows parity remain separate.

## Author checks and limits

Independent sol-2 static contract review4095 approved the original enum and
registration facts. Root accepted the separate Qt-version/metatype boundary
recorded after4127. This is not candidate code approval.

The first binding probe exposed an autocxx type-name error. The corrected probe
compiled. A plain Rust CXX declaration binds the global QMetaObject. Autocxx
creates constructor/value wrappers. Generated C++ stays outside source.
The first application build exposed a private Rust module. Explicit reexports
fixed it. Failed logs and generated files remain in the private evidence packet.

On system Rust1.98.1 and Qt6.11.2, the final locked tests pass without warnings.
Two unit tests verify all30 original values, signed32 Rust storage, and the native
metaobject's two enums with no methods, properties, constructors, or superclass.
The QtQml runtime test verifies all30 values, the original nested expressions,
no zero keys, exact `enums only` creation rejection, and version rejection.
The initial doctest invocation used an unconfigured rustup shim. The successful
run explicitly uses system rustdoc. It has zero doctests.

Registration cache, error types, and process-lifetime metadata retention are
independent Rust adapter policies. Qt documents free() for unregistered snapshots.
The original BusinessLog module has no logging side effects. Separate on-demand
and BusinessLogger enum metatype edges do not become application code here.
Rust enum storage checks do not validate Qt enum metatypes. No newer native enum
metatype API, vendor execution, C++ ABI parity, full Main startup, or Windows
parity is claimed. Independent exact-candidate code review remains required.

The local checkpoint is `8b7ef30`. It preserves work before the main advance.
A normal merge at `53043ba7e9e44225fe006a0a9ab92fddec736518` adds fresh main
`d922d46337150db102cef675073cfa392ef92bbc`. That main is an ancestor.
No original QML or resource file changed. All current open claims are outside
this owned scope. No source was pushed or published.

The final system cargo-clippy all-target check passes with warnings denied.
The generated autocxx module has a narrow Qt enum-name lint allowance. It keeps
Qt's exact `QMetaObject::Call::CustomCall` name. The application Rust has no
blanket lint allowance. An exact source rerun of locked native/QML tests also
passes after that lint-only change. See [selected checks](../evidence/gui-business-log/checks.json).
