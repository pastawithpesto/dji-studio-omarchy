# Rust host for the original QML

The Rust host is in `rust/host`. It loads the exact original entry
`qrc:/qml/Main.qml` and adds the original import root `qrc:/`. Its build uses
`original/original.qrc` without a resource or QML change. That collection has
1,826 unique aliases and 410 QML files. The launcher has no replacement screen
or placeholder native controller. Missing modules cause an error and exit 1.
This is host infrastructure. Original Main startup and full GUI behavior remain
unfinished.

The internal crate and executable name `original-qml-host` is an independent
implementation name. It is not an original DJI product name. The registration
callback runs after application creation and before engine creation. The combined
candidate must connect that callback to the supported original native types.

## Build and check the Rust host

Requires system Rust, a C++17 compiler, Qt 6 with Core, Gui and Qml development
files, and the QML modules imported by the source. This candidate pins CXX-Qt,
CXX-Qt-Lib and CXX-Qt-Build to 0.10.0. The author checks use Qt 6.11.2 and Rust
1.98.1. Use an owned target directory outside the source tree.

```sh
CARGO_TARGET_DIR=/absolute/owned/host-target RUSTC=/usr/bin/rustc QMAKE=/usr/bin/qmake6 \
  /usr/bin/cargo build --manifest-path gui/rust/host/Cargo.toml --locked
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  /absolute/owned/host-target/debug/original-qml-host --check
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 CARGO_TARGET_DIR=/absolute/owned/host-target \
  RUSTC=/usr/bin/rustc QMAKE=/usr/bin/qmake6 /usr/bin/cargo test \
  --manifest-path gui/rust/host/Cargo.toml --locked --test qt_runtime
```

`--check` is an internal diagnostic flag. It loads the original root and exits
without the event loop. `--help` prints command syntax. Other arguments exit 2.
Use environment variables for Qt platform selection. Normal launch
enters the Qt event loop only after root creation succeeds. This error handling
is independent launcher policy. Qt prints its actual source locations and import
errors. The host does not suppress them. A test checks a real original resource,
the original Config module, the missing-resource signal, and event-loop exit.
Test-only QML is not application UI.

The registration callback returns an explicit result. Normal launch stops on a
registration error. `--check` reports that error and still attempts the original
Main load, to expose further import errors. It returns failure if registration
or root creation fails.

The local Qt 6.11.2 host build passed. The focused runtime test passed. The exact
original Main check exited 1 with the following actual import errors. Source
lines refer to `original/resources/qml/Main.qml`. Each import has version 1.0.

| Line | Missing module |
| --- | --- |
| 8 | FpsDetect |
| 9 | CloudAlbumManager |
| 18 | UserGuideMaskManager |
| 19 | UserGuideTypeModel |
| 20 | BusinessLogger |
| 21 | BusinessLog |
| 22 | WindowPositionDetector |
| 23 | ViewModeAnalyzeController |
| 24 | ProjectStateController |
| 25 | SettingPanelViewModel |

These are first-stage errors. They do not prove that all other imports, types,
context objects, singletons, or startup actions work. Further errors can appear
after these modules exist. The registered WindowPositionDetector boundary and
its native screen access require a separate check. On this computer,
`QT_FORCE_STDERR_LOGGING=1` sends Qt diagnostics to captured stderr.

## Binding boundary

Application and test source is Rust. Original UI source is QML. CXX-Qt generates
C++ bridge code. Qt's `rcc` generates resource C++. CXX-Qt-Lib includes upstream
C++ wrappers, and Qt itself is C++. Thus this is not a wholly C++-free stack. The
host adds no handwritten `.cpp`, `.h`, or inline C++ payload.

The current official [CXX-Qt releases](https://github.com/KDAB/cxx-qt/releases)
list 0.10.0. The [builder API](https://docs.rs/cxx-qt-build/0.10.0/cxx_qt_build/struct.CxxQtBuilder.html)
provides `.qrc` resource compilation. The
[engine API](https://docs.rs/cxx-qt-lib/0.10.0/cxx_qt_lib/struct.QQmlApplicationEngine.html)
provides import paths and root-creation signals. Official
[Qt Bridge 0.3 documentation](https://doc-snapshots.qt.io/qtbridge-rust/qtbridge/index.html)
requires Qt 6.10 or later. Its public `QApp` API does not expose the engine or
root-creation signal needed here. Its runtime uses CXX-Qt internally. The direct
CXX-Qt host makes the failure check available. Native QWindow and QScreen support
requires a separate verified boundary.

## Historical package boundary

The former C++ host and independent `NativeStitchedFlow.qml` screen did not load
original Main. Their historical build and test results do not apply to this Rust
host. The source audit found frozen backend identity mismatches for `.gitignore`,
`Cargo.toml`, and `src/lib.rs`; the historical builder stopped at `.gitignore`.
This host does not repin or bypass that invariant. Historical source, evidence,
and the frozen backend/resource records remain separate.

The Rust host has no processing CLI linkage or new media controls. Its standalone
build does not prove that the previous package builds, that original Main works,
or that media, project, camera, GPU, failure, or Windows behavior matches DJI
Studio. See the [original resource record](original/README.md) for the exact
resource bundle and its limits.
