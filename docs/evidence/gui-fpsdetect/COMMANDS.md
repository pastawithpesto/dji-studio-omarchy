# FpsDetect reproducible native family

Application and fixture checkpoint: `c6d699faef0b09e88bbacfc1308b9d4170e2146b`.
Compiler checkpoint: `dbd4988c99cbf38467b90dc896d435709eaff711`.
The compiler's shared signal and qualification options have independent source
review and focused regression passes. This command uses the exact immutable
compiler directory and a target reserved for that derivative. The generator
source path appears explicitly in `qt-check-03.log`. Focused native runs 13 and
14 pass; the final run adds the original-versus-modern class-info assertion. See [results and limitations](CHECKS.md).

```sh
flock /home/violence/Projects/dji-studio-omarchy/coordination/gui-three-sol-20261013-build.lock \
  env CARGO_BUILD_JOBS=1 \
  CARGO_TARGET_DIR=/home/violence/Work/dji-gui-three-sol-20261013/qt-shared-handler-target \
  RUSTC=/usr/bin/rustc RUSTDOC=/usr/bin/rustdoc \
  QMAKE=/usr/bin/qmake6 QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 1200 /usr/bin/cargo test \
  --manifest-path /home/violence/Work/dji-gui-three-sol-20261013/fpsdetect/gui/rust/fpsdetect/qt/Cargo.toml \
  --locked --offline --features test-fixture --test qt_runtime \
  --config 'patch.crates-io.cxx-qt-gen.path="/home/violence/Work/dji-gui-three-sol-20261013/signal-shared/gui/rust/userguide-type-model/vendor/cxx-qt-gen"'
```

The portable lockfile records the local compiler package without an absolute
path. Root owns the combined host's patch configuration. Registry CXX-Qt 0.10.0
alone lacks the required shared callback option and original namespace fix.

System tools: rustc/rustdoc `1.98.1 (48a229cea 2026-09-01)`, qmake `3.1`, Qt
`6.11.2` under `/usr/lib`. The test-fixture feature binds native QObject children
and metadata, a QQmlContext property, checked FpsDetect casting, and Qt DeferredDelete flushing
only for this test. It registers a separate TestPump fixture; it introduces no
FpsDetect property, signal, or public QML slot. All fixture bridge sources share
the production bridge source directory, as QmlModule requires.
