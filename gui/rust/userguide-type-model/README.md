# UserGuideTypeModel 1.0

This crate registers the original creatable QObject types `UserGuideType` and
`MoueseEventType`, with all16 original `EnumType` values and spellings. Call
`userguide_type_model::register_types()` on the application thread after
application construction and before any QML engine. Its return type is `()`.
Repeated calls are idempotent. Keep the Qt type registry for the process lifetime.

Registration executes the generated Qt callback eagerly and protects this pure
enum module from duplicate plugin registration. Both original enum names are
published before an engine exists. No application methods or properties are
added. Original QML and resources remain unchanged.

The pinned Rust generator adds an explicit unscoped member-enum option. Both live
QObject enums have `isScoped()==false`. Its default output is checked against
immutable released snapshots and an independently generated raw stock fixture.
There is no handwritten C++ application payload or emitted-code patch.

The native harness checks both names before any enum reflection, then verifies
native enum identity, size4, alignment4 and signed enumeration flags0x14. It
checks all16 QML values, both creatable types, distinct instances, zero declared
methods/properties/constructors, the extra modern `QML.Element` class-info row,
wrong-major rejection and subsequent valid engines.

This adapter is tested with system Rust1.98.1, CXX-Qt0.10.0 and Qt6.11.2 on a
64-bit host. It uses a pinned private Qt registration entry point. The native
value probe compiles the official Qt header itself with GCC to obtain class size
and alignment, then checks Rust storage before use. The build rejects unaudited
Qt versions and pointer widths. Run serially under the granted build lock with
one Cargo job and an external target, using offscreen Qt for headless tests.

[Evidence and limitations](../../../docs/evidence/gui-userguide-type-model/README.md)
separate the recovered application API from Qt metadata/version, Windows and full
GUI parity. Clippy checks the application package with `--all-targets --no-deps`;
strict whole-workspace Clippy exposes two retained upstream generator lints.
