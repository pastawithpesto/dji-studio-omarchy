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
QT_QPA_PLATFORM=offscreen /absolute/owned/host-target/debug/original-qml-host --check
QT_QPA_PLATFORM=offscreen CARGO_TARGET_DIR=/absolute/owned/host-target \
  RUSTC=/usr/bin/rustc QMAKE=/usr/bin/qmake6 /usr/bin/cargo test \
  --manifest-path gui/rust/host/Cargo.toml --locked --test qt_runtime
```

`--check` loads the original root and exits without the event loop. Normal launch
enters the Qt event loop only after root creation succeeds. This error handling
is independent launcher policy. Qt prints its actual source locations and import
errors. The host does not suppress them. A test checks a real original resource,
the original Config module, the missing-resource signal, and event-loop exit.
Test-only QML is not application UI.

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

## Existing experimental package

The following record concerns the prior C++ host and independent screen. It does
not describe this Rust host. The frozen backend identity check remains in place.
The source audit found mismatches for `.gitignore`, `Cargo.toml`, and `src/lib.rs`;
the existing builder stopped at `.gitignore`. This host does not repin or bypass
that check. A standalone host build does not prove that the existing package
builds or that the full GUI works.

# Experimental native stitched workflow

This is the unchanged Qt 6.11.2 C++/QML composition from standalone GUI2dc6ae8 (independent approval795), reused through prior unioneb444938. Author grant1030 repins the builder to exact approved backend e03c38da6e430214f7a41cb0ecbd063e4ac29178 (254 files, independent combined metadata/finite-DOM approval1024). All254 backend files are frozen in backend-source-manifest.json; GUI host/QML/tests/resources and Rust processing bytes remain unchanged. Metadata and finite-DOM modules introduce no new GUI controls or project workflow. Exact current GUI/source/package review is separate and required before publication. It does not implement original Main, native services/controllers, projects, timeline, export queue, camera stitching, gestures or cloud workflows. Layout, transport and default rendering remain independent design choices, not recovered vendor internals or same-UI claims.

Historical unioneb444938 was rejected by independent review938 because standard default-thread backend demux tests failed their non-timeout fixture timing gate. Its source/package successes and serial/isolated passes did not waive that failure. The separately approved current backend includes the bounded fixture repair; this repin must pass its own single standard test gate without retries or source changes after a failure. Original headed SIGKILL865 remains unexplained; later passes do not erase it. Full original UI/UX, Windows/camera, project and full processing parity remain unverified.

## Build and run

Requires installed Qt6.11.2 Core/Gui/Qml/Quick/QuickControls2/Multimedia/Svg/Test, CMake, a C++20 compiler, system Cargo/Rust, FFmpeg with v360/libx264, and FFprobe. No binding crate, dependency installation or global environment change is performed. The command works from another checkout; choose your own fresh external output directory:

```
python3 gui/build.py --output /absolute/external/owned-build
/absolute/external/owned-build/bundle/native-stitched-flow
python3 gui/tests/validate.py --bundle /absolute/external/owned-build/bundle \
  --tests /absolute/external/owned-build/qt-build/flow-tests \
  --output /absolute/external/fresh-validation --headed
```

Remove `--headed` for offscreen transport/decoding tests. The software scene-graph backend in the tested offscreen configuration decodes frames but does not visibly draw video; visible preview validation uses the actual Wayland/default rendering path and an independent gradient pixel check. The headed test changes only its own window to fullscreen because the compositor can override minimum window sizes. An ordinary tiled window below the declared minimum780×640 can clip the independent layout. Headed tests close their own window normally.

Build outputs stay external to Git. Existing output directories with unknown ownership are refused; rebuild logs remain separate. The package records actual CLI/FFmpeg/FFprobe hashes and versions. Render resolves FFmpeg through a controlled package PATH; the unchanged metadata CLI uses `/usr/bin/ffprobe` directly. Thus the current Linux package requires that path and rejects a differing requested probe. Move/rebuild the package on another installation to refresh pinned paths and hashes. Linked Qt/codec libraries are system dependencies, not bundled or cryptographically attested by this executable hash check. Qt Multimedia uses its own installed backend and reports its actual version separately.

## Actions and boundaries

Select a readable regular local file using an absolute lossless UTF-8 file URL. Remote hosts, query/fragment, NUL, lossy filenames and paths exceeding32768 encoded bytes are refused. Paths retain OS symlink semantics. Declare that the input is already stitched equirectangular media; metadata success never sets that declaration. Choose a new absent `.mp4`; existing entries, including dangling symlinks, are rejected and checked again before submission.

Metadata executes exactly `CLI --metadata INPUT` and shows separate raw capped diagnostics. An exit0/no-direct-track result is diagnostic only. Reframe executes exactly `CLI INPUT OUTPUT`: existing independent defaults yaw0/pitch0/HFOV90,1920×1080,libx264 CRF20,yuv420p,optional AAC,faststart. No settings are silently accepted or ignored.

Only one immutable job is active. Separate65536-byte diagnostic tails are continually drained in bounded chunks and displayed at10Hz, with truncation/replacement markers. Inspection deadline120s and output-frame verification deadline30s use timers; rendering has no invented progress/timeout. A successful CLI exit and new ordinary nonempty output establish file creation only. Output readiness additionally requires a real1920×1080 frame under that job/source token; the fresh Qt presenter then pauses. Play/Pause labels follow actual playback state and real errors clear readiness while preserving the exported file. One first frame is not proof of complete-stream correctness.

Normal close is refused during launch/run/check/cleanup, keeping the event loop responsive. There is no Cancel. Error/deadline cleanup verifies actual PID/start/session/group and descendant identity through `/proc`, then signals only corroborated members via Linux pidfds: TERM,2s timer,KILL if necessary. It waits for direct QProcess completion and no live owned group members. Unknown, escaped or reused identities remain explicitly pending without unverified signalling. Sampling cannot prove attribution of a previously unseen descendant that escaped and lost its parent before observation. Orphan zombies are not claimed to be host-reaped; the direct child is reaped by Qt. Forced host SIGKILL cannot guarantee cleanup, and partial/exported files are retained. Installed-kernel pidfd and readable `/proc` support are required; unsupported ownership/permission paths remain pending.

Open output folder calls QDesktopServices with the real directory. A true return records launch submission, not external file-manager appearance. URL-handler tests verify the exact directory/submission. Optional `tests/observe_folder.py` separately observed a fresh Nautilus window whose title exactly names the owned output directory on this Omarchy installation; it does not inspect folder contents or close/signal desktop processes. `tests/observe_package.py` observes and normally closes only the fresh package window identified by its actual PID/start/session/address. These native observations do not establish Windows equivalence or general desktop coverage.

Ordinary dev/inode/size/mtime checks before/after processing detect tested input changes. They do not create immutable contents or eliminate all path/content/backend TOCTOU races. No automatic overwrite, deletion or retry occurs.

## Resource provenance and validation

Frozen contract SHA13dc8440f94d9ca453d53109876f920634e24a99a44cc36a8c763b41e00feda0; original DJI Studio1.0.0.30839 EXE SHAe8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4. `resource-manifest.json` pins1458 original aliases plus unchanged complete LightTextButton/ImageButton and three palette files to extraction paths/raw offsets/byte hashes. Full manifest SHA443a67dc71ef6a07df4619a52507b1491267eaab3b999ba5f6b19dca5e2f1b98 is checked by the verifier and application. Resource files retain their original notices. Packaged original QML modules are not imported wholesale. Only the five explicitly registered subset components are loaded; the new entry is `/native/NativeStitchedFlow.qml`.

Validation generates a tiny synthetic stitched coordinate-gradient video, exercises real CLI/Qt/QML, checks output codec/dimensions/all20 frames, independently checks25 pinhole projection samples with channel tolerance8, and compares the entire decoded RGB stream of CLI/QML/direct-FFmpeg outputs. Injected process fixtures cover real nonzero/crash/start/ENOSPC/deadline/cleanup failures; they are transport-only test programs. GUI tests use actual control clicks/focus/disabled state/close refusal, multimedia errors and stale queued tokens. All evidence/build binaries/screenshots/media stay outside source Git. Camera files, Windows UI/media/project/failure comparisons, audible/audio-output equivalence, GPU/driver coverage and full feature parity remain missing.
