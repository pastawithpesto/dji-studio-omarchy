# UserGuideTypeModel static contract and Rust checks

Reference: DJI Studio1.0.0.30839. Executable SHA-256:
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
This packet records static facts from original PE bytes. It does not record
vendor execution or a Windows reference comparison.

The publisher at `0x1406775f3..0x140677627` passes URI
`UserGuideTypeModel`, major1, minor0, and two type names to registration wrappers.
The wrappers resolve to `0x140646350..0x140646444` and
`0x140644930..0x140644a24`. Both build `QQmlPrivate::RegisterType` version2
records and call the imported `QQmlPrivate::qmlregister` with kind0. Both records
have objectSize16 and nonnull create callbacks. The kind is ordinary creatable
QObject registration. It is not singleton or uncreatable registration.

The callbacks resolve to `0x140638fb0..0x140638fd1` and
`0x140638b70..0x140638b91`. Each calls IAT `0x1436e0490` with a null parent,
sets its own vtable, and returns. The original import table identifies the call
as Qt6Core.dll `??0QObject@@QEAA@PEAV0@@Z`, or `QObject(QObject*)`.
No other application initialization occurs in either callback.

[static-api.json](static-api.json) contains both original revision11 metadata
headers, enum rows, strings, numeric values, and selected import identities.
`UserGuideType` has ten values. `MoueseEventType` has six values. Both have one
`EnumType` with original flags0 (unscoped), zero class-info rows, zero methods, zero properties, and zero declared
constructors. Each includes inherited QObject behavior. Preserve `UNKOWN`,
`MoueseEventType`, and `REALSE` exactly. They are original spellings.

[qml-callsites.json](qml-callsites.json) pins the seven original importing QML
files and every original enum reference. QML uses `UserGuideType`. This audit
finds no `MoueseEventType` expression in the original QML. The native registration
still makes that second type part of the module API.

The Rust crate uses two creatable CXX-Qt QObject declarations and ordinary Qt
QObject ownership. It adds no application methods or properties. CXX-Qt0.10.0
rejects explicit qenum discriminants. Its generated values are contiguous from
zero. The two internal alias namespaces prevent a generated C++ alias collision.
They do not change the original QObject names or each nested `EnumType` name.
The source order therefore follows the exact native metadata rows. The pinned local Rust generator emits an unscoped enum for the explicit
`qenum_unscoped` marker and uses the correct qualified CXX alias ID on that path.
Released default behavior remains unchanged, with a raw stock fixture comparison
in addition to immutable formatted snapshots. Actual live QObject tests verify
`isScoped()==false`, all16 independent numeric expectations, distinct creatable
instances and zero declared methods/properties/constructors. Corrected spellings
remain absent. Both original types support construction; neither original record
has an invalid-construction rule.

Original publisher edges after `0x140677627` explicitly register
`UserGuideType::EnumType` and `MoueseEventType::EnumType`. The separate signed32
interfaces have size4, alignment4 and flags0x14. Their helper chain calls imported
`QMetaType::id` and `registerNormalizedTypedef`; it is not a revision11 enum
metatype slot. The supplemental original byte contract has independent review.
The harness queries BOTH exact names before any enum lookup or engine, then
checks native identity, size, alignment and signed enum flags.

The generated registrar is normally lazy. `register_types()` calls the pinned
Qt6.11.2 private `QQmlMetaType::qmlRegisterModuleTypes` callback once, without
constructing an engine, then calls public `qmlProtectModule` to skip duplicate
plugin registration. The module contains only its registered native types.
The Qt source path and protection policy are independent adapter details, not
newly inferred original DJI behavior. Registration repeated twice and later
engines are checked. Unsupported major2 is rejected; this modern path reports a
protected-module registration error rather than an original Windows diagnostic.

Modern Qt adds exactly one `QML.Element` class-info row per type. The original
class-info count is zero. This extra count/name is tested and explicitly retained.
Qt6.11.2 also exposes grouped `Type.EnumType` objects even for these unscoped
enums. The test records that observed extra access; original Qt6.5.3 runtime
behavior was not executed. These framework differences prevent a claim of
identical QObject metadata, all-version behavior or ABI parity.

The reflection value storage is derived from the pinned Qt6.11.2 headers.
A native GCC class-layout probe compiles the official `QtCore/QMetaEnum` header
itself: QMetaEnum16/8, QMetaType8/8, TypeFlags4/4 (size/alignment). It generates
Rust assertion constants checked before any native value is used. CXX also
checks native trivial relocation. An initial autocxx POD probe incorrectly
emitted one-byte opaque values and crashed; systemd core/GDB established the
cause. The unsafe probe and each failed build are retained. The corrected test
has no application C++ input. Qt6.11.2 and64-bit guards bound this private layout.

Full raw evidence, failed probes, the source audit script, selected original
byte ranges, objdump assembly, saved-record pins, and test logs stay in the local
project archive at `reconstruction/root-gui-three-sol-20261013/userguide-type-model`.
Saved wrapper assembly comes from `sol-fast-review/ui-controllers`, not a new
REA decompilation. This task independently checks those saved bytes against the
pinned PE. New constructor and metadata checks use offline Python PE decoding
and GNU objdump. The first decoder attempt used the wrong QMetaObject pointer
index and failed. The corrected decoder follows the saved revision11 layout.

The initial owned REA setup was commit
`2c7240cf9d8231e16ad01de7678af9dbd01bab46`, package6.4.0, Ghidra12.1.4.
Root later recorded official commit `fa4b8288655188426222773ead2ccbdaf76334fd`
in its additive REA setup record. There is no running owned MCP server. No new import or current-tool decompilation
is claimed by this packet. Static registration and Linux runtime checks are
separate from complete Main startup, Windows behavior, and full GUI parity.
