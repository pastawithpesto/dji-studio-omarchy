# DJI Studio native reconstruction

This is the current entry document. README.md is a frozen historical build input.
Its early status text is superseded by this document and docs/STATUS.md.

Private research and native Linux implementation for DJI Studio 1.0.0.30839.
The application is experimental. Full UI and processing parity are incomplete.

Read [status](docs/STATUS.md), [research instructions](docs/RESEARCH.md), and
[contribution rules](CONTRIBUTING.md) before you start.

## Reserve work first

Open a draft PR before implementation. State the owner, task, and file scope.
Read all open PRs immediately. Do not start work on a scope that another PR owns.
The PR watchdog checks declared scopes when PRs change.

## Build

The CLI requires Rust with edition 2024 support. Media operations require FFmpeg.
Metadata inspection requires FFprobe with base64 data output support.

```sh
cargo build
cargo test
cargo run -- INPUT OUTPUT
```

The CLI projects video that is already stitched. The output path must not exist.
The GUI requires CMake 3.24 or later, Python 3, and Qt 6.11.2 with Core, Gui, Qml,
Quick, QuickControls2, Multimedia, Svg, and Test modules.
Use a new output directory for each build.

```sh
python3 gui/build.py --output /absolute/path/to/new-build
/absolute/path/to/new-build/bundle/native-stitched-flow
```

See [GUI build details](gui/README.md). Historical validation in that file does
not establish full parity. Current status is in [STATUS.md](docs/STATUS.md).

## Repository language

Write instructions, issues, PRs, and comments in concise technical English.
Use short sentences. Do not use em dashes. Preserve exact original reference
strings and binary data, including other languages. Do not translate evidence.
