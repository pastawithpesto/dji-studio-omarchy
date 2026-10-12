# WindowPositionDetector Qt adapter

This crate connects the reviewed Rust integer policy to the original Qt API.
The QML module and type are `WindowPositionDetector`, version `1.0`.
The invokable methods retain `isWindowCompletelyOnScreen(QWindow*)` and
`resetWindowToBestScreen(QWindow*)`. Call `register_types()` after construction
of `QGuiApplication`, before loading QML. The host must keep Qt objects on the
GUI thread.

The adapter uses `QWindow::geometry`, `QScreen::geometry`, the native screen-list
order, and a lazy `QGuiApplication::primaryScreen` query. It skips null screen
pointers. A null window returns false for the predicate and does not move for
reset. Reset reads the selected screen geometry again, reads window width and
height twice, and calls `QWindow::setPosition(int,int)` once. It uses the existing
Rust policy for endpoint arithmetic, intersection scores, ties and clamping.
The safe Rust `Window` and `Screens` traits are independent test interfaces.
Qt rectangles are copied to Rust endpoint values without normalization.

Application source in this directory is Rust. CXX-Qt 0.10.0 generates C++ QObject,
metacall, registration and call glue. Qt and `cxx-qt-lib` also contain library C++.
This is not a C++-free stack. No handwritten C++ application file or inline C++
payload is added.

The library does not supply `QList<QScreen*>` directly. Its documented
`QListElement` extension supplies the container implementation and layout.
Build-time autocxx 0.30.0 generates exact `ScreenList` and `ScreenPointer` aliases
from installed Qt headers. CXX declarations use these aliases and existing
library templates. The Rust pointer wrapper is transparent and non-owning.
The code does not guess mangled symbols or define a new Qt container layout.
`src/aliases.rs` is generator input, not a compiled Rust module. The general
autocxx QObject-method probe was unsuccessful. Only its alias generator is used.
CXX 1.0.205 and cxx-gen 0.7.205 are pinned to matching bridge ABI versions.
The failed 1.0.194 runtime versus 0.7.205 generator link is preserved.
The earlier autocxx generated Rust incompatibility does not apply: that Rust
output is not compiled. Failed earlier probes remain in the local evidence.

Build requirements are Qt 6 Core, Gui and Qml development packages, `qmake6`,
a C++ compiler and libclang. Set `QMAKE` for an alternate compatible installation.
Use an external build directory. The native test must run on a process main
thread; its Cargo target sets `harness = false`.

```sh
CARGO_TARGET_DIR=/absolute/new-target cargo build --manifest-path gui/rust/qt/Cargo.toml --locked
QT_QPA_PLATFORM=offscreen CARGO_TARGET_DIR=/absolute/new-target cargo test --manifest-path gui/rust/qt/Cargo.toml --locked
```

Focused tests check native module registration, exact invokable names, QML
conversion of null and a real QWindow pointer, and the offscreen move request.
Ordered synthetic calls check early return, skipped null entries, empty versus
nonempty fallback, positive ties, selected-geometry rereads and repeated window
getters. Pointer-list tests check the library extension's storage operations.
These tests do not load original Main or compare with Windows.

Qt documents that some window systems do not support setting or querying top
level window positions. Offscreen movement does not prove Wayland movement,
Windows geometry, DPI, screen order or original application behavior. The
adapter does not substitute `availableGeometry`, force a screen, or add a new
platform movement policy. Original QML and resources remain unchanged.

Source evidence is the existing `../lib.rs` and
`../../docs/window-position-contract.md`. DJI Studio 1.0.0.30839 method report
SHA-256 is `e2656e1fdac02ba295a1e85626d66fe666c9777cdc200a78c6f26da85f85989c`.
Qt rectangle report SHA-256 is
`3e88512a524b99cf4b3668cfdb93d5e945a3008849c1a40d33fc434536545fc5`.

Primary binding and platform documentation checked during implementation:

- [CXX-Qt external Qt declarations](https://kdab.github.io/cxx-qt/book/bridge/extern_cppqt.html)
- [CXX-Qt Rust Qt declarations and QML registration](https://kdab.github.io/cxx-qt/book/bridge/extern_rustqt.html)
- [QList custom element support](https://docs.rs/cxx-qt-lib/0.10.0/cxx_qt_lib/struct.QList.html)
- [Autocxx concrete aliases](https://docs.rs/autocxx/0.30.0/autocxx/macro.concrete.html)
- [Qt QWindow geometry and position contract](https://doc.qt.io/qt-6.11/qwindow.html)
- [Qt QScreen geometry](https://doc.qt.io/qt-6.11/qscreen.html)
- [Qt Bridge 0.3 API](https://doc-snapshots.qt.io/qtbridge-rust/qtbridge/index.html)

The public Qt Bridge 0.3 interface did not supply the required screen-list and
QWindow boundary. CXX-Qt declarations and generated aliases preserve those
interfaces. Exact-candidate independent source review and separate milestone
verification remain required. Native test success is a bounded Linux result.
