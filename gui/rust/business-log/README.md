# BusinessLog 1.0

This independent Rust crate exposes the exact original `BusinessLog` enum
namespace. It registers URI `BusinessLog`, version1.0, and type `BusinessLog`.
The type rejects construction with the original text `enums only`.
It supplies the complete signed32 `Stream` and `Events` tables.
It has no logging service, properties, or application methods.

Call `register_types()` on the application thread after QCoreApplication
construction (QGuiApplication also works) and before QML load. Registration is cached once per process.
The registered metaobject stays allocated for the process lifetime because Qt
keeps its pointer. Do not clear the Qt type registry in this process.
Allocation and registration errors are independent adapter errors.

CXX-Qt0.10.0 does not support explicit enum values. This crate uses autocxx0.30.0
to generate bindings to Qt's `QMetaObjectBuilder` and `QMetaEnumBuilder`.
Qt Core private development headers are required.
The [Qt6.11.2 builder source](https://raw.githubusercontent.com/qt/qtbase/v6.11.2/src/corelib/kernel/qmetaobjectbuilder.cpp)
documents snapshot ownership and free() cleanup. The build reads their paths and
version from QMAKE. These private Qt APIs can change between Qt releases.
Application source is Rust. The bindings and Qt dependencies contain C++.
No handwritten C++ source or inline C++ application payload is present.

Use an external target directory. The task resource grant requires the shared
build lock, one Cargo job, and offscreen Qt tests. See the local task plan.

```sh
CARGO_BUILD_JOBS=1 CARGO_TARGET_DIR=/absolute/owned/target \
  RUSTC=/usr/bin/rustc RUSTDOC=/usr/bin/rustdoc QMAKE=/usr/bin/qmake6 \
  /usr/bin/cargo test --manifest-path gui/rust/business-log/Cargo.toml --locked
```

Set `QT_QPA_PLATFORM=offscreen` and `QT_FORCE_STDERR_LOGGING=1` for the QML test.
The tests check the native enum-only metaobject and all30 original enum values, the original nested enum expressions,
the absence of a named zero value, version1.0, and the exact creation rejection.
Its QML fixture is test source. It does not replace original UI source.

The [static contract](../../../docs/evidence/gui-business-log/README.md) pins
original source identity and evidence. Linux Qt test results and the original
static contract are separate evidence. Full original Main startup, BusinessLogger
behavior, and Windows parity are outside this crate.
