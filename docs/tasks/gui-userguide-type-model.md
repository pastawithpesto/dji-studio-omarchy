# UserGuideTypeModel Rust registration

Owner: sol-2. Local instruction4065 reserves this task. The user requests local
work only. Do not create a PR, push, merge, or release this work.

Initial source: main `7a5d360342267cce0d05670a413c893407ec8d04`, fetched on
2026-10-13. This commit is an ancestor of the owned branch
`local/gui-userguide-type-model-20261013`. Initial worktree status was clean.
Read-only open PR claims have no overlap with this new component.

Scope: `gui/rust/userguide-type-model/**`, this task file, and
`docs/evidence/gui-userguide-type-model/**`. Root owns host integration.
Preserve every original QML file and resource.

Reference: DJI Studio1.0.0.30839, executable SHA-256
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
Recover the registration kind, exact enum names and values, and full supported
API from original PE bytes and saved analysis. Keep full raw records outside
source in `reconstruction/root-gui-three-sol-20261013/userguide-type-model`.

Plan: verify two registration records and complete metaobject tables; verify
constructor call edges; write the independent Rust/CXX-Qt crate; test both
original names and every original enum value in QML; obtain independent review
of the exact candidate. Request a resource grant before new REA queries or Qt
builds. Source identity and static API evidence do not establish Windows parity.

The recovered module is `UserGuideTypeModel 1.0`. It registers two creatable
QObject types: `UserGuideType` and `MoueseEventType`. The original spelling is
retained. Each type declares one `EnumType` enum and no properties or methods.
Its create callback calls `QObject(QObject*)` with a null parent and sets its
vtable. It has no additional application state initializer.

Fresh main `d922d46337150db102cef675073cfa392ef92bbc` was merged after a local
checkpoint; it remains an ancestor. Static contract4094, supplemental enum
registration4140, generator source4119/4232 and stock default output comparisons
have separate independent evidence. The final corrected module has actual native
QML/metadata checks. Root owns combined host integration and final cyclic review.

The implementation uses an explicit unscoped Rust generator option, exact alias
IDs, engine-free eager enum publication and module protection. The reflection
probe checks compiler-derived native sizes/alignment before value use. Original
application API completion is distinct from the additional `QML.Element` row,
modern grouped enum access, protected-module policy/unsupported-version error,
Qt6.11.2 private metadata ABI, Windows behavior and full Main startup.

All failed probes and the diagnosed one-byte autocxx POD crash remain in the
private project archive. Application-only Clippy preserves two unrelated stock
vendor lint failures. Public check records and exact final handoff are separate
from author source notes. All commits, reviews and artifacts stay local.
