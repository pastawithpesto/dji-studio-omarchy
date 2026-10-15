# FpsDetect checks

Application and fixture source: `c6d699faef0b09e88bbacfc1308b9d4170e2146b`.
Attribution-only main `d922d46337150db102cef675073cfa392ef92bbc` was merged at
`2bd65458ddc61d0acd143a631fe0f1eb2aef102b`. Original QML and resources are unchanged.

The original executable SHA-256 and all nine saved byte ranges pass readback.
The bounded original callback, getter, import, and signal contract passed separate
Sol High static review in bus `4096`. Code acceptance is a separate review.

Five Rust-only test groups pass: signed counter wrap; nine fixed timeout vectors
and reset; mixed durations and strict threshold; one clock read per frame;
reentrant field reloads with the cached initial budget. These core files are
unchanged since the recorded successful checkpoint `570e18d`. Final system
rustfmt, application-language, and whitespace checks also pass.

## Native result

Focused native runs 13 and 14 exit zero. Run 14 checks the final source above:

- Original creatable FpsDetect 1.0, QQuickItem base, read-only int fps, native
  `fpsChanged(int)` and `renderTime(double)`, two local methods and one property.
- Seven actual native window signal pairs, timer publication, empty-sample reset,
  signal names/arguments/order, and the conditional second renderTime emission.
- Nested emission of the actual child QTimer timeout, including live field reloads
  and the original initial-budget comparison.
- Deferred destruction and destruction while the Rust timer callback remains
  active. For the latter, QML destroy() returns before a shared native subscriber
  flushes DeferredDelete, respecting the QtQml JavaScript lifetime boundary.
- Exactly one local `QML.Element` class-info row from modern registration;
  original bounded metadata has zero. This is an explicit registration artifact.

All six generated signal callback handlers take an immutable handler reference.
The compiled binding asserts the FpsDetect opaque Rust representation has size
zero and alignment one. This supports the bounded shared-callback lifetime
assessment; runtime success alone does not prove Rust aliasing rules.

Private logs under the assigned external fpsdetect research directory:

| Artifact | Result | SHA-256 |
| --- | --- | --- |
| qt-check-13.log | exit 0 | `79dcc655d62233b66b128fe8cf6501a63077f1b7cd62c6dcc3e191087f231ed1` |
| qt-check-14.log | exit 0 | `34ef7ab45ea128fefe49cce7913a013447b1e682b5ea77a9036c517bf0d94d87` |

The final build retains one generated dead-code warning: the external Rust
before_rendering and after_rendering emitter methods are unused. Their connection
helpers are used. No dependency-wide Qt Clippy pass is claimed.

## Preserved failures and repairs

Private logs remain intact, including failed results before each repair.
The initial system-tool selection and inherited-window unsafe annotation were
corrected. Generated signal namespace lookup required root's reviewed Rust
compiler derivative. Its first const-signal regression used an unsupported
RustQt fixture; the replacement uses the supported external C++Qt declaration.

Runs 03 through 10 exposed test-fixture source-directory, static-member,
foreign-type method, unsupported attribute, cast inference, and duplicate thunk
problems. Native QObject metadata inspection and local opaque test views resolve
those issues without generated C++ edits. Renaming a bridge module alone did not
resolve the duplicate QTimer cast helper.

Run 11 aborts on QtQml's forbidden deletion of an object during its active
JavaScript signal expression. This is a preserved unsupported test operation,
not a safety pass. The final native-subscriber fixture flushes deletion only
after the JavaScript handler returns. Run 12 fails linking feature-gated CXX
symbols omitted by build-time feature evaluation; an explicitly conditional,
separate plain CXX test bridge repairs it. Runs 13 and 14 then pass.

The Rust frame mutex, owner thread assertions, and owner-lifetime flag are
explicit independent safety policies. The adapter retains the original
AutoConnection/DirectConnection kinds and repeated window connections. No Rust
owner or frame borrow crosses user handlers. Qt 6.11.2's tagged QObject source
shows a slot-object guard during direct functor invocation; that source fact is
separate from the identity of the loaded `/usr/lib` libraries. See
[Qt's pinned QObject source](https://raw.githubusercontent.com/qt/qtbase/v6.11.2/src/corelib/kernel/qobject.cpp).

Reference arithmetic, native registration, graphics output, and Windows behavior
are separate results. Full GUI and Windows parity are not established by this
bounded module check. Reproduce it with [the recorded command](COMMANDS.md).
