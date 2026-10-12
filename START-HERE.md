# DJI Studio native reconstruction

This is the current entry document. README.md is a frozen historical build input.
Its early status text is superseded by this document and docs/STATUS.md.

Research and native Linux implementation for DJI Studio 1.0.0.30839.
The application is experimental. Full UI and processing parity are incomplete.

Read [status](docs/STATUS.md), [research instructions](docs/RESEARCH.md), and
[contribution rules](CONTRIBUTING.md) before you start.

## Reserve work first

Open a draft PR before implementation. State the owner, task, and file scope.
Read all open PRs immediately. Do not start work on a scope that another PR owns.
The hosted PR watchdog has successful manual and automatic PR target-event runs.
Read the current monitoring status in docs/STATUS.md.

## Build

The CLI requires Rust with edition 2024 support. Media operations require FFmpeg.
Metadata inspection requires FFprobe with base64 data output support.

```sh
cargo build
cargo test
cargo run -- INPUT OUTPUT
```

The CLI projects video that is already stitched. The output path must not exist.
The Rust GUI host loads the original QML resource bundle. Original application
startup is incomplete because native DJI modules are missing. The custom C++
host and its simplified screen have been removed from the current source.

Local host checks use Qt 6.11.2 with Core, Gui, Qml and the QML import modules.
CXX-Qt generates binding code during the build. Qt and this generated code use
C++; application source is Rust and QML. Use an external build directory.

```sh
CARGO_TARGET_DIR=/absolute/path/to/new-build QMAKE=/usr/bin/qmake6 \
  cargo build --manifest-path gui/rust/host/Cargo.toml --locked
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen \
  /absolute/path/to/new-build/debug/original-qml-host --check
```

The check returns failure while original native services remain unavailable.
See [GUI build details](gui/README.md) and [current status](docs/STATUS.md).

## Repository language

Write instructions, issues, PRs, and comments in concise technical English.
Use short sentences. Do not use em dashes. Preserve exact original reference
strings and binary data, including other languages. Do not translate evidence.
