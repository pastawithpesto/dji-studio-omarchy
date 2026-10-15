# FpsDetect

This crate implements the original FpsDetect arithmetic. The `qt` subcrate
registers the original creatable QQuickItem type `FpsDetect` in URI `FpsDetect`,
version `1.0`. Root must call `fpsdetect_qt::register_types()` after creating
QGuiApplication and before loading QML. Original QML and resources are unchanged.

The original constructor creates a 1000 ms QTimer. Each window change adds
beforeRendering and afterRendering connections. The first starts QElapsedTimer
with AutoConnection. The second counts a frame and records elapsed whole
milliseconds with DirectConnection. The timer publishes read-only `fps` and
emits `renderTime(double time)`, `fpsChanged(int fps)`, and the original conditional
second `renderTime` emission. The adapter uses real Qt timer and render signals.
It does not supply a fixed fps value.

Rust protects the frame fields and native QElapsedTimer with a mutex. The
original bytes show no lock. This is an independent memory-safety choice. The
adapter releases the frame lock before signals call user code. It retains prior
window connections, as the original callback does. Connection guards remove
handlers when the Rust object is destroyed. The child QTimer has the same GUI
thread and parent as the original. Rust deletes it before the QObject base
destructor runs. Timer and window callback assertions check the owner thread before either
callback uses its owner pointer. This is an independent safety check.

The timer caches the initial integer frame budget, then reloads fps and mean
after user handlers in the original order. The adapter clones frame state and
an owner-lifetime flag before calling handlers. Destruction clears that flag
before dropping connections or the child timer. Later emissions check it before
using the owner again. This is an explicit safety policy for owner destruction.
All six signal bindings opt into the coordinator's reviewed shared callback
trampoline. Handlers use Fn + Send + Sync and immutable callback references.
Registry CXX-Qt 0.10.0 alone lacks this option and the original namespace fix;
root owns the host's compiler patch configuration.

The exposed original API has no writer for fps or additional invokable methods.
Internal Rust names `FpsDetectRust`, `after_rendering`, and `timeout` are adapter
names. QML names retain the original spelling. Qt, CXX-Qt, and generated binding
code remain C++ dependencies. No application C++ source or inline C++ is added.

## Checks

Use the coordinator's serial build lock and owned target. Rust-only checks:

```sh
RUSTC=/usr/bin/rustc /usr/bin/cargo test --manifest-path gui/rust/fpsdetect/Cargo.toml --offline
```

Qt checks use `QT_QPA_PLATFORM=offscreen`, `QT_FORCE_STDERR_LOGGING=1`,
`QMAKE=/usr/bin/qmake6`, and `CARGO_BUILD_JOBS=1`. The test constructs a real
FpsDetect in test-only QML, verifies read-only fps and inherited QQuickItem
properties, supplies seven native window render signals, and checks timer
publication, signal arguments/order, and the next empty sample. It also checks
actual nested child-timer emission, deferred destruction, and destruction during
an active Rust timer callback after the JavaScript handler returns. Native
metadata checks preserve the original int/double signal types and explicitly
record the modern QML.Element class-info artifact. Reference tests
cover mean calculations, signed counter wrap, integer threshold division, strict
threshold comparison, negative elapsed values, and state reset.
They also check one clock read per frame and that
reentrant samples change the published fields while preserving the first budget.

The focused native family passes. See [the reproducible native command](../../../docs/evidence/gui-fpsdetect/COMMANDS.md),
[check results](../../../docs/evidence/gui-fpsdetect/CHECKS.md), and
[the static contract](../../../docs/evidence/gui-fpsdetect/CONTRACT.md).
These checks do not establish graphics output or Windows parity. Full original
GUI startup remains a separate host integration result.
