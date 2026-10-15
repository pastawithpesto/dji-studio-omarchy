# FpsDetect static behavior contract

Reference: DJI Studio `1.0.0.30839`, `DJI Studio.exe`, SHA-256
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
Image base: `0x140000000`. Addresses below are virtual addresses.

This packet extends the saved declaration evidence with bounded original-byte
inspection. GNU objdump `2.47` supplies the assembly. Root grant `4082` permits
this inspection. No vendor code or new Ghidra import runs. The complete private
captures remain in the assigned external research directory.

## Static facts

The registration packet uses ordinary Qt TypeRegistration. It exports URI and
type `FpsDetect`, version `1.0`. Its factory is `0x140093a68`; its static
metaobject is `0x142fdc800`. The class derives from QQuickItem. The constructor
at `0x141393500` calls the imported QQuickItem constructor. It clears the fields
for published fps, mean time, frame count, and elapsed sum. The getter thunk
`0x1400d0b3e` resolves to `0x141394190`; that body reads the fps field at `+0x20`.
Thus the initial read-only `int fps` property is zero.

The original metadata declares `fpsChanged(int fps)` and
`renderTime(double time)`. The bounded original revision-11 metadata header
declares zero local class-info rows, two methods, one property, and two signals. Modern Qt registration adds
one local `QML.Element` class-info row; the native probe checks that exact name
and count. This is an explicit registration artifact, not a claim of full QObject
ABI parity. The original native class name is `FpsDetect::FpsDetect`.

The signal thunks resolve to `0x1414a1d60` and
`0x1414d7c50`. Those bodies activate local signal indices zero and one against
the same metaobject.

The constructor creates a child QTimer. It connects timeout to slot object
callback `0x1413941a0` with AutoConnection. It connects its own windowChanged
signal to slot object callback `0x1413942f0` with AutoConnection. It starts the
QTimer with interval `1000` milliseconds.

The window callback ignores the signal argument and reads the current window.
If that window is null, it returns. Otherwise it connects beforeRendering to
`0x1413942b0` with AutoConnection, and afterRendering to `0x141394540` with
DirectConnection. It does not remove previous connections in this callback.
The beforeRendering callback starts the QElapsedTimer at `+0x38`.
The afterRendering callback increments the 32-bit frame count at `+0x30`, reads
QElapsedTimer::elapsed(), converts its signed 64-bit milliseconds to double,
stores the last duration at `+0x48`, and adds it to the sum at `+0x50`.

The timeout callback performs these actions in order:

1. Copy frame count to published fps.
2. Store mean elapsed milliseconds as `sum / signed(frame count)`. Store zero
   when the frame count is zero.
3. Clear frame count and elapsed sum.
4. Cache `double(1000 / fps)`, or zero for zero fps. The division is signed
   integer division. This budget survives calls to user signal handlers.
5. Emit renderTime with the initial mean.
6. Reload the current published fps and emit fpsChanged, even if unchanged.
7. Reload the current mean after that handler. Emit renderTime with this mean
   again if it is strictly greater than the cached budget multiplied by `0.8`.

A reentrant timeout can change the fields between emissions. The original
callback reloads those fields; it does not dispatch an immutable signal list.
The Rust core's convenience `timeout()` returns the ordinary non-reentrant
sequence. The Qt adapter uses `begin_timeout()` and performs the live reloads.

The original `comisd` and `jbe` instructions suppress the extra emission for
equal or unordered values. The constant at `0x141e97e78` is IEEE-754 double
`0.8`, bytes `9a9999999999e93f`. The duplicate signal is original behavior.
The counter increment wraps as a 32-bit instruction. No elapsed-time clamp or
floating-point normalization occurs.

## Evidence pins and limits

External packet prefix:
`/home/violence/Projects/dji-studio-omarchy/reconstruction/root-gui-three-sol-20261013/fpsdetect/`.

| Artifact | SHA-256 |
| --- | --- |
| OFFLINE-ANALYSIS.json | `f998a1ff61efaf65ec6375c954644a52bd701f8198173b320291f5380f9ee252` |
| OFFLINE-FOLLOWUP.json | `92bb2d6da6b628c3fc02c1acccc09aebcebbd8ef68fb38693883907e74ac0433` |
| OFFLINE-CALLBACKS.json | `12141ceaee43ac4ea0762fb03ce16aad1dc87aec97ce5da753dbc27797b27fa1` |
| CLASSINFO-ORIGINAL.json | `f29f50618f48d4d7ed712ef437a8db93285f24afc04e7d943c789415d1110ffc` |

The PE exception directory splits callbacks into multiple fragments. The
follow-up captures include the reachable continuations through each return.
Extra padding and adjacent bytes in bounded captures do not belong to the
claimed callback bodies.

The saved 410-file QML scan contains only two FpsDetect import lines. It has no
direct object construction or member use. The metadata and native callback
contract still require an actual creatable type with these behaviors.

Qt clock behavior, invalid QElapsedTimer reads before its first start, render
thread scheduling, Linux graphics output, and Windows reference behavior remain
separate runtime questions. Independent Sol High static review passed in bus
`4096`. Its private report has SHA-256
`25824b38de72017d417dfd0c030f21a4bf6b3a643589683c8a85d188b38fb64f`.
That verdict approves the bounded original-byte contract. Code review remains
separate. No UI or Windows parity claim follows from this packet.
