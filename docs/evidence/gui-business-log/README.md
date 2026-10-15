# BusinessLog static contract

The selected [contract](contract.json) records all30 original enum entries.
The original type is an enum namespace. It is not the BusinessLogger service.

The source is DJI Studio 1.0.0.30839. Its EXE SHA-256 is
`e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`.
The registration call at `0x14068b1e7` imports
`qmlRegisterUncreatableMetaObject`. Its arguments are the metaobject at
`0x1430cc950`, the URI `BusinessLog`, version1.0, the type name `BusinessLog`,
and the exact reason `enums only`. The saved assembly covers the caller
`0x14068a730..0x14068b53c`. The selected instruction bytes match the pinned EXE.

The metaobject has no superclass or static metacall. Its string table is at
`0x1430cc990`. Its revision11 metadata is at `0x1430ccc80`. The header has zero
methods, properties, constructors, and class information. It has two enum records.
Both records have flags2. Thus they are scoped enums and are not flags.
The Stream record has seven entries. The Events record has23 entries.

The enum type interfaces are at `0x1434e7530` and `0x1434e7650`.
Both have size4, alignment4, and type flags `0x14`. This is a relocatable
signed enumeration. The unsigned enumeration flag `0x100` is absent.
The key/value metadata uses32-bit words. Both `UNKNOWN` values have bytes
`ffffffff`, which represent -1. No named entry has value0.

The original QML audit finds the import at `qml/Main.qml:21` and the member
reads at line693. `BusinessLog.Stream.APP_LAUNCH` equals1.
`BusinessLog.Events.LOAD_EDITOR_QML` equals11. The audit includes nearby
BusinessLogger references to keep the service distinction explicit.

This is offline inspection of original bytes and reuse of saved assembly.
It is not new REA decompilation or vendor execution. Full original Main startup
and Windows behavior remain separate checks. Full raw evidence and failed probes
remain outside source at
`reconstruction/root-gui-three-sol-20261013/business-log` in the research project.

## Qt version and metatype boundary

The original `Qt6Core.dll` is version6.5.3.0. Its SHA-256 is
`7da66834f98bcf7b05e285fe6ea2c03951aef596876caa9e42897bfa7d6f623b`.
Its export table has `QMetaEnum` names, keys, values, and scope methods.
It has no `QMetaEnum::metaType` export. The official [Qt6.5.3 header](https://raw.githubusercontent.com/qt/qtbase/v6.5.3/src/corelib/kernel/qmetaobject.h)
also has no such member. Revision11 uses five words per enum and does not have enum
metatype slots. BusinessLog's metatype array at `0x1430ccdd8` contains the void
interface at `0x1434c1770`. It does not contain either enum interface.

The two signed enum interfaces are separate layout witnesses. Their three
absolute pointer sites each are in BusinessLogger's method metatype array.
That service's metaobject is at `0x1430ccde0`. On-demand ID/typedef helpers
use the interfaces at `0x14171c940` and `0x14171c9c0`. Legacy registration
callbacks reach these helpers through separate wrappers. The selected
BusinessLog registration call passes the enum namespace metaobject. It does not
pass an enum interface. No separate explicit startup publisher edge was proved
for this module. Broader startup and dynamic reachability remain unresolved.

The Linux adapter uses the current Qt builder's32-bit key/value table. It does
not add newer `QMetaEnum::metaType` behavior or BusinessLogger registration
side effects. Rust size/alignment checks validate Rust enum storage. They do
not validate a Qt enum metatype. The native and QML checks validate the bounded
original enum surface. They do not establish C++ ABI or complete Qt-version parity.

The original namespace, all30 values, and the exact registration arguments passed
independent static review in bus4095. This approval is separate from candidate
code review and native tests.
