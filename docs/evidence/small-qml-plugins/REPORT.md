# Three next smallest Qt QML plugins

New static analysis of three 28,856-byte DLLs from DJI Studio 1.0.0.30839. The two smaller native MSVC DLLs and API-set family already have saved packets. These are the first three next native files tied at this size in the preserved size order. No claim is made that these are the only files at this size.

| Shipped file | Original class | Original URI | Metadata payload |
| --- | --- | --- | --- |
| labsanimationplugin.dll | QtLabsAnimationPlugin | Qt.labs.animation | 101 bytes |
| qmlfolderlistmodelplugin.dll | QmlFolderListModelPlugin | Qt.labs.folderlistmodel | 111 bytes |
| labsmodelsplugin.dll | QtQmlLabsModelsPlugin | Qt.labs.qmlmodels | 101 bytes |

Each exports ordinal1 `qt_plugin_instance` at0x180001160 and ordinal2 `qt_plugin_query_metadata_v2` at0x180001290. LLVM and binutils independently agree with the original PE export maps. There are no export forwarders.

## Captured coverage

Each newly analyzed DLL has103 provider-discovered file-backed executable functions, including31 thunks:28 direct external import thunks, two internal free alias chains and one internal guard-dispatch thunk. All103 dossiers, separate pseudocode and assembly outputs were captured. All106 complete body ranges per DLL match original file bytes, totaling4,942 unique function bytes. Every one of the53 original pdata entry starts is contained in a captured body. Across the three DLLs this is309 functions,318 ranges and14,826 function bytes.

Nine additional provider witnesses cover the complete virtual file-backed .rdata, .pdata and .qtmetad sections, totaling24,735 bytes. All match the original files. Original complete SHA-256 values remain unchanged. The saved packet contains the full raw captures and compatible immutable snapshots locally. Selected export output and indexes are published here. These counts describe captured static bodies. They do not prove that all hidden code, external behavior or runtime states are recovered.

## Factory and lifetime

The exported factory at0x180001160 uses the CRT thread-local initialization guard and registers a cleanup callback at0x1800024b0. It tests the saved reference-data pointer, its32-bit field at offset4 and the saved object pointer. If those tests do not supply a live object, it allocates0x18 bytes through0x180001338, calls the imported QQmlEngineExtensionPlugin constructor with a null parent, writes class vtable pointers at object offsets0 and0x10, and obtains reference data through the imported QtSharedPointer helper. The old reference record is decremented atomically and freed when its prior counter was1. The function returns the object pointer only when the recorded offset4 field is nonzero.

The cleanup callback atomically decrements the saved reference counter and frees its record when the prior counter is1. Do not infer complete Qt object lifetime or concurrent-call safety from this wrapper. Qt reference helper behavior, allocator/CRT outcomes and external QObject behavior remain outside this packet.

At 0x180001020 the constructor-like body calls the base constructor, writes both vtable pointers, and loads the local module-registration thunk address 0x1800012b0 into RAX. That thunk jumps through IAT slot 0x180003118 to the imported module-registration function. The constructor-like body does not call the thunk or the imported registration function. The decompiler renders a return value; that rendering is not an original C++ constructor declaration. Loading or returning this address does not establish that module registration executes here.

The observed registration imports are `qml_register_types_Qt_labs_animation`, `qml_register_types_Qt_labs_folderlistmodel` and `qml_register_types_Qt_labs_qmlmodels`, from Qt6LabsAnimation.dll, Qt6LabsFolderListModel.dll and Qt6LabsQmlModels.dll respectively. Their implementations are external to these small plugins. This packet does not recover the animation or model algorithms in those larger DLLs.

## Metadata and class routing

The metadata export writes the pointer0x18000700c and the101/111/101-byte length into the caller return buffer, then returns that buffer. The bytes include the four-byte header01/06/05/00 and the complete CBOR map. The source section begins12 bytes earlier with the exact `QTMETADATA !` magic. The map identifies the interface `org.qt-project.Qt.QQmlEngineExtensionInterface`, the original class and the URI array in the table above.

The header interpretation and16-byte pointer/size structure are consistent with the [official Qt6.5.3 qplugin.h definitions](https://github.com/qt/qtbase/blob/v6.5.3/src/corelib/plugin/qplugin.h). Numeric CBOR keys2 and3 correspond to IID and className in [Qt's metadata key definitions](https://github.com/qt/qtbase/blob/v6.5.3/src/corelib/plugin/qplugin_p.h). The header records metadata format1 and Qt major/minor6.5. It does not identify the patch version or prove loader compatibility.

At0x180001110 a null class-name input returns null. An exact original class-name string returns the original object pointer; other names go to the imported base qt_metacast. At0x1800010e0 the body selects an imported dynamic metaobject when the recorded QObjectData field is nonzero, otherwise its local static metaobject. Destructor-like wrappers at0x1800010a0 and0x180001090 call the imported base destructor, optionally free the object when the low flag bit is set, and apply the observed0x10 this-pointer adjustment. ABI/type labels are decompiler-derived unless the exact bytes or linked Qt definition support them.

## Tools, warnings and limits

Official latest upstream REA was fetched at task start:4573e8cf35de822bfc5feabcc89ec3717c247c8c, package and running MCP server6.4.0. Ghidra12.1.4 and JDK21 produced the new native captures. The owned installation and stdio session do not change the shared MCP server. Exclusive shared import ownership was held for each phase. A768M heap setting was passed; its -Xmx translation was checked in the pinned launcher source. A later live-process probe ran after cleanup and observed no JVM. Do not present that probe as a live heap observation.

The initial phase is fresh function analysis with separate baseline dossier, pseudocode and assembly calls. The second phase imports matching same-tool snapshots to add missing data witnesses; it does not repeat function decompilation. No optimization is adopted or timing comparison made.

Forty functions per DLL preserve Ghidra jumptable/indirect-transfer warnings, including import thunk paths. All native parameter types, external effects, hidden functions, full call closure, exception behavior, loader behavior and Qt runtime results remain qualified. No vendor DLL was executed. No Rust/native implementation or GUI change was made. No camera, Windows, UI or application parity is claimed. Independent packet review and separate verification are required before acceptance.

## Additive count correction

The initial sealed report called every provider thunk an import thunk. The corrected count above distinguishes28 direct external targets, two internal free aliases and one internal guard dispatcher per DLL. The initial report, failed assumption and raw manifest remain unchanged. See THUNK-COUNT-CORRECTION.json. No source bytes or309-function coverage count changed.

The additive publication correction is recorded in `PUBLICATION-CORRECTION-R2.json`. Earlier reports and the initial raw seal remain preserved.
