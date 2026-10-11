# FpsDetect original-byte and QML callsite closure

Owner: `luna-b-3`, root instruction 1282. Scope: the original `Main.qml` import of `FpsDetect 1.0`, the same import in the 410-source corpus, and only the direct QML references in those importing files. This is a static evidence packet for a future real adapter. It does not cover `ProjectStateController` or other Main dependencies and makes no claim that a recovered/root-visible window is the vendor UI.

## Pinned inputs and method

The reference is `extracted/1.0.0.30839/DJI Studio.exe`, build 1.0.0.30839, SHA-256 `e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4`. It is PE32+ with ImageBase `0x140000000`. VA-to-file-offset conversion uses the executable's section table; the exact relevant byte slices, file offsets, lengths and per-slice SHA-256 values are in [raw-byte-ranges.json](raw-byte-ranges.json). End addresses in this report are exclusive. Bounded objdump outputs are preserved beside this report.

The 410-alias corpus and the corrected source corpus are pinned by the B1 inventory and report: [qml-alias-inventory.json](../../../luna-b-1/ui-parity-20261011/structure-correction/qml-alias-inventory.json) (SHA-256 `940dbb8122e0d0b22948db13f037d609e132fa23213aa82e0e20cad8ea619094`) and [B1 structure-correction report](../../../luna-b-1/ui-parity-20261011/structure-correction/REPORT.md) (SHA-256 `42695580d0b3699f678a0b8a47c5eb065565570686da476a05651aa6e9ed24d3`). All 410 files were re-read and matched the inventory SHA values before lexical scanning; there were zero missing files and zero hash mismatches. The Qt headers below are supporting format/enum references, not proof of the runtime Qt build. Their hashes are pinned in `input-pins.json`.

## Registration and construction evidence

| Claim | Exact evidence | Static conclusion and limit |
|---|---|---|
| Registration callsite | Main-executable `.text`: caller function `[0x140676b20,0x140678e6b)`, RVA `0x676b20`, `.pdata` record at file `0x35b7784`. At `0x14067753f..0x140677559`, instructions load the same literal at VA `0x141eb1480` into RCX and R9, set EDX=1 and R8D=0, then call thunk `0x1400048a4`. The thunk bytes at file `0x48a4` jump to `0x140643a30`. | The bytes pass URI `FpsDetect`, version 1.0, element name `FpsDetect` to this registration helper. This is a static registration packet/call edge, not proof startup reaches it or Qt accepts it at runtime. The literal is in `.rdata`, file `0x1eb0080`, RVA `0x1eb1480`. |
| Registration record | Helper `[0x140643a30,0x140643b24)`, RVA `0x643a30`, `.pdata` record file `0x35b2f54`; complete bounded listing in `registration-disasm.txt`. At `0x140643a5b` it stores structVersion 2; at `0x140643a78` it stores `0x68`; at `0x140643a7f` it stores factory pointer `0x140093a68`; at `0x140643aaf` it stores static metaobject pointer `0x142fdc800`; `0x140643af1` clears ECX and `0x140643af3` calls IAT `0x1436e1f20`. | The stack record matches Qt `QQmlPrivate::RegisterType` version 2 under the saved Qt `qqmlprivate.h` layout (header SHA-256 `c90948bfd270eb639943f18ab8bbcfa233dfc047fab02e267b38217dc494395a`, `RegisterType`/`StructVersion` and fields at lines 436-462). The source enum calls registration kind 0 `TypeRegistration` at line 739. The record's 0x68 object-size field, factory and metaobject pointer are static facts. Return value is preserved in EAX; no runtime result was observed. |
| Factory and constructor | Registration factory pointer `0x140093a68` is a thunk to `[0x1406388d0,0x1406388fb)` (RVA `0x6388d0`, `.pdata` record file `0x35b2240`). It calls `0x1400bfc71`, then writes two vtable pointers at object offsets `+0` and `+0x10`. That thunk resolves to constructor `[0x141393500,0x14139373c)` (RVA `0x1393500`, `.pdata` record file `0x364df34`). | The constructor directly writes zero to fields `+0x20` (dword), `+0x28` (qword), `+0x30` (dword), then makes an indirect call with `this+0x38`; it zeros qwords `+0x48`, `+0x50`, `+0x58`, `+0x60`, and subsequently assigns pointer/helper state and invokes more indirect calls. Exact body: `constructor-disasm.txt`. These are constructor writes/call boundaries only. The indirect targets/member meanings, property-to-field relation, whether they succeed, and observable initial `fps` are unknown. Do not equate zeroed storage with the QML property's initial value. |
| Static metacall edge | Metaobject slot contains VA `0x14000c784` (file `0xbd84`); its five-byte thunk jumps to `[0x141463910,0x14146399f)` (RVA `0x1463910`, `.pdata` record file `0x36575f4`). | This is the class's bounded static metacall target. Its body has an in-range branch for method indices 0 and 1, loading the respective `int`/`double` argument and tail-jumping to `0x14005fce0` / `0x14001a89d`. The dispatcher also branches to `0x1414639b8`, beyond this `.pdata` interval. I did not attribute names or behavior to those targets or extend that out-of-range fragment. No complete getter/setter implementation boundary was recovered. |

The byte correction for the static-metacall address is deliberate: qword bytes at metaobject offset `+0x20` decode little-endian to `0x14000c784`, not `0x1400c784`.

## Native API declaration recovered from static metadata

The registered metaobject pointer is `0x142fdc800` (file `0x2fdb400`). Its string-data/table and metadata bytes are preserved in `raw-byte-ranges.json`; relevant strings begin at VA `0x142fddfc0`, file `0x2fdcbc0`. The raw string records decode to `FpsDetect::FpsDetect`, `fpsChanged`, `fps`, `renderTime`, and `time`.

The metadata header at `0x142fdec80` is `[11,0,0,0,2,14,1,32,0,0,0,0,0,2]`: revision 11, two methods, one property, no enums, no constructors, two signals. This layout agrees with the saved Qt 6.5.3 `QMetaObjectPrivate` definition (SHA-256 `993f89fcad35fe8f6501524b318ad43e03275d6107bd6285853cf722ce704aa4`, lines 170-190); revision 11 also agrees with its explicit output-revision note. The method/property rows are decoded using its saved metadata definitions and the Qt metatype IDs in `qmetatype.h` (SHA-256 `9375fb0b0d60ca4d96cbae77f9432996bbf857464cbf42673092302215bb5838`, lines 343-356).

| Local index | Native declaration in metadata | Raw metadata row / parameter data |
|---|---|---|
| Signal 0 | `void fpsChanged(int fps)` | Method row at `0x142fdecb8`: `[1,1,26,2,6,2]`; parameter record at `0x142fdece8`: `[Void(43),Int(2),name-index 3]`. Signal bit is `0x4` in flags `0x6`. |
| Signal 1 | `void renderTime(double time)` | Method row at `0x142fdecd0`: `[4,1,29,2,6,4]`; parameter record at `0x142fdecf4`: `[Void(43),Double(6),name-index 5]`. Signal bit is `0x4` in flags `0x6`. |
| Property 0 | `int fps`, readable, not writable; notify signal index 0 (`fpsChanged`) | Property row at `0x142fded00`: `[name-index 3,type-index 2,flags 0x15001,notify-index 0,revision 0]`. Saved Qt property flags define Readable=`0x1`, Writable=`0x2` (qmetaobject header lines 34-50), so the writable bit is clear. |

There are no enum rows, extra properties, or constructor rows in this metaobject. These are declared signatures and access flags, not proof of actual signal emission, property updates, timing, sampling algorithm, thread behavior, or native registration success.

## Direct QML references and all-410 search

The pinned 410-alias scan [qml-fpsdetect-scan.json](qml-fpsdetect-scan.json) verifies each source SHA and finds exactly two files importing `FpsDetect 1.0`:

- `/qml/Main.qml`, source SHA-256 `ca96f270f65ce8ebb5ffe0038e00ea6d39f46df62f57511dd2a4f363b62c477e`, line 8.
- `/qml/controller/UserGuideMask.qml`, source SHA-256 `9142d534ad4ff5b356a8604f5f2414747d51ed7f0c320b0e654364bc0b546bdd`, line 8.

Each file has exactly one `FpsDetect` token, its import line. The corpus scan found no `FpsDetect` construction, member access, or call at any other source line in either file, and no occurrence in the other 408 source files. Thus the module import appears in two QML files, while the type exported as `FpsDetect` is not constructed or referenced in these 410 recovered sources. This does not rule out dynamic strings, compiled QML outside the corpus, or native use outside these files. The two imports do not establish that the module was ever loaded at runtime.

## Unresolved implementation work and limits

- No PDB was found in the workspace file inventory. No REA Evidence ID or disassembler database was used in this packet; the findings are reproducible from pinned PE bytes, bounded disassembly, source corpus, and saved Qt header artifacts.
- The direct factory-to-constructor edge is recovered, but constructor helper/indirect-call targets and member roles remain unresolved. Constructor bytes do not reveal a defensible initial value for property `fps`.
- The static metadata gives the property and signal declarations. The property accessor/setter body and signal emission behavior are not recovered. The static-metacall body's out-of-range branch was not followed.
- Static registration setup does not prove which startup path invokes it, successful registration, QML instantiation, or observed Windows behavior. No native execution, live REA import, app launch, compilation, or Windows comparison was performed.
- Generic `fps` identifiers elsewhere are not treated as uses of this imported native type.

This is the finite two-module result. It is useful for an adapter signature boundary, but not a behavioral implementation contract or UI parity approval. Review status: **unreviewed**; independent Sol/Astra review remains required.
