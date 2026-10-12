# QQuickFileNameFilter static contract

This report records bounded static facts from the shipped `Qt6QuickDialogs2Utils.dll`. It does not describe a completed feature or a tested user interface.

## Source and method

The source is DJI Studio 1.0.0.30839 `extracted/1.0.0.30839/Qt6QuickDialogs2Utils.dll`. It is 45,240 bytes. Its SHA-256 is `580d8be7657cd4b074b5d4ee43bc8c325d501aea737ef15c13e41f62bd0da263`. The independent verifier reads the original file and checks the complete source identity before checking evidence.

The capture used official REA commit `fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d`, REA package and running server version 6.4.0, Ghidra 12.1.4, Node 26.9.0, and a 768M Ghidra heap. Attempt 02 captured 17 exported functions in one private Ghidra session. Attempt 03 captured three called helpers and one data range in a second private session. The sessions ran in sequence under the shared import lock. Both used the same source hash and analysis profile. The DLL was not executed.

The full raw REA dossiers, pseudocode, assembly, snapshots, and request records remain in the local packet at `/home/violence/Projects/dji-studio-omarchy/reconstruction/luna-dialogutils-20261012`. The published [source map](SOURCE-MAP.json) contains each selected full function byte span, exact export name, Ghidra evidence ID, pseudocode digest, relevant import boundary, and original string bytes. The [verifier](verify_source_map.py) checks this map against the original DLL. The [verification result](INDEPENDENT-VERIFICATION.json) records the final checks. [Verification history](VERIFICATION-HISTORY.json) preserves two corrected validation failures. The [artifact manifest](MANIFEST.json) pins the published evidence files.

## Selected source ranges

All ranges below use inclusive VA endpoints from the Ghidra FunctionManager body. The byte map contains each complete body as hexadecimal bytes. The three `FUN_` names are Ghidra database labels. They are not original exported names.

| ID | Original export or internal label | RVA | Full VA range, inclusive | Bytes |
|---|---|---:|---|---:|
| F01 | `??0QQuickFileNameFilter@@QEAA@PEAVQObject@@@Z` | `0x1c50` | `0x180001c50–0x180001ca4` | 85 |
| F02 | `?index@QQuickFileNameFilter@@QEBAHXZ` | `0x2910` | `0x180002910–0x180002913` | 4 |
| F03 | `?setIndex@QQuickFileNameFilter@@QEAAXH@Z` | `0x3140` | `0x180003140–0x18000317c` | 61 |
| F04 | `?update@QQuickFileNameFilter@@QEAAXAEBVQString@@@Z` | `0x3380` | `0x180003380–0x180003e0c` | 2701 |
| F05 | `?nameFilter@QQuickFileNameFilter@@AEBA?AVQString@@H@Z` | `0x29d0` | `0x1800029d0–0x180002a9a` | 203 |
| F06 | `?nameFilters@QQuickFileNameFilter@@AEBA?AV?$QList@VQString@@@@XZ` | `0x2aa0` | `0x180002aa0–0x180002b9e` | 255 |
| F07 | `?options@QQuickFileNameFilter@@QEBA?AV?$QSharedPointer@VQFileDialogOptions@@@@XZ` | `0x2ba0` | `0x180002ba0–0x180002bcf` | 48 |
| F08 | `?setOptions@QQuickFileNameFilter@@QEAAXAEBV?$QSharedPointer@VQFileDialogOptions@@@@@Z` | `0x3180` | `0x180003180–0x1800031f8` | 121 |
| F09 | `?name@QQuickFileNameFilter@@QEBA?AVQString@@XZ` | `0x2980` | `0x180002980–0x18000299e` | 31 |
| F10 | `?extensions@QQuickFileNameFilter@@QEBA?AV?$QList@VQString@@@@XZ` | `0x2520` | `0x180002520–0x180002549` | 42 |
| F11 | `?globs@QQuickFileNameFilter@@QEBA?AV?$QList@VQString@@@@XZ` | `0x28b0` | `0x1800028b0–0x1800028d9` | 42 |
| F12 | `?qt_static_metacall@QQuickFileNameFilter@@CAXPEAVQObject@@W4Call@QMetaObject@@HPEAPEAX@Z` | `0x1450` | `0x180001450–0x1800016a1` | 594 |
| F13 | `?qt_metacall@QQuickFileNameFilter@@UEAAHW4Call@QMetaObject@@HPEAPEAX@Z` | `0x2bd0` | `0x180002bd0–0x180002c53` | 132 |
| F14 | `?indexChanged@QQuickFileNameFilter@@QEAAXH@Z` | `0x2920` | `0x180002920–0x180002954` | 53 |
| F15 | `?nameChanged@QQuickFileNameFilter@@QEAAXAEBVQString@@@Z` | `0x29a0` | `0x1800029a0–0x1800029ce` | 47 |
| F16 | `?extensionsChanged@QQuickFileNameFilter@@QEAAXAEBV?$QList@VQString@@@@@Z` | `0x2550` | `0x180002550–0x18000257e` | 47 |
| F17 | `?globsChanged@QQuickFileNameFilter@@QEAAXAEBV?$QList@VQString@@@@@Z` | `0x28e0` | `0x1800028e0–0x18000290e` | 47 |
| H01 | `FUN_180002580` | `0x2580` | `0x180002580–0x1800028a0` | 801 |
| H02 | `FUN_180001e60` | `0x1e60` | `0x180001e60–0x180001f27` | 200 |
| H03 | `FUN_1800017b0` | `0x17b0` | `0x1800017b0–0x1800018c6` | 279 |

The PE has 24 exports. An independent PE parser and LLVM 22.1.8 `llvm-objdump -p` output agree on every ordinal, RVA, and exact name. The [LLVM export output](llvm-exports.txt) is preserved.

## Direct static facts

### Index field and setter

F01 stores the 32-bit value `-1` at `this+0x10`. It initializes a `QString` at `this+0x18`. It zeros the three 8-byte slots at `this+0x30`, `+0x38`, and `+0x40`, the three slots at `this+0x48`, `+0x50`, and `+0x58`, and the two pointer slots at `this+0x60` and `+0x68`.

F02 returns the 32-bit value at `this+0x10`. F03 compares its 32-bit input with that field. If the values are equal, its branch goes to the epilogue without a store or activation call. Otherwise, it stores the input at `this+0x10`. It then reaches the call through IAT slot `0x180005278`, with a reference to `staticMetaObject` at RVA `0x57b0` and numeric activation ID `0`. The input value is placed in the local argument payload. The [LLVM `setIndex` disassembly](llvm-setIndex.txt) and verifier both confirm these finite branch and address facts. This function body contains no range check or clamp.

### Update path

F04 reads the old 32-bit index and snapshots the cached name, extensions, and globs. It calls F06 to obtain `nameFilters()` from the stored options. It walks that list in order. The code checks each item length and calls the Ghidra-labeled external `QT6CORE.DLL::QtPrivate::equalStrings`. On the first true result, it stores that list position at `this+0x10` and stops the loop. If the loop finds no equal item, it stores `-1`. F04 writes the field directly. It does not call F03 on this path.

F04 constructs a `QChar` with value `0x28`, calls the Ghidra-labeled `QT6CORE.DLL::QString::indexOf`, then calls `QT6CORE.DLL::QString::left` and assigns the result to the `QString` at `this+0x18`. Under ordinary Qt semantics, this sequence appears to retain the prefix before the first `(`. The imported implementations were not analyzed. The claim about the resulting text is an inference from their imported names and the call sequence.

F04 calls H01 with output storage at `this+0x30` and `this+0x48`. It compares the saved index with the new index. If they differ, it calls `QMetaObject::activate` with numeric ID `0`. It calls H02 for the old and new name, then activates ID `1` if the helper reports inequality. It calls H03 for old and new extension lists, then activates ID `2` on inequality. It calls H03 for old and new glob lists, then activates ID `3` on inequality. These calls occur in index, name, extensions, and globs order. The helper return values and the branch direction are direct code facts. The imported Qt activation implementation is outside this packet.

### Filter-list helper and comparison helpers

H01 initializes both output lists. It calls `QtPrivate::findString` with `QChar(0x28)` and `QtPrivate::lastIndexOf` with `QChar(0x29)`. It enters the parse block only when the first returned position is nonnegative and is less than the last returned position minus one. It takes a middle view beginning one position after the first result. It calls `QStringView::split` with `QChar(0x20)` and literal integer arguments `1, 1`.

For each returned view, H01 calls `QtPrivate::findString` with `QChar(0x2e)`. It calls `QContainerImplHelper::mid` using the returned position plus one and length `-1`. It appends that resulting `QString` to the list at the second argument. It appends the full token to the list at the third argument. F04 passes the extension storage as the second argument and glob storage as the third argument. The QChar values are `(`, `)`, space, and `.`. The likely interpretation is a parenthesized space-separated pattern list, a suffix after the first period, and a full token. That interpretation depends on the unresolved Qt search, split, and middle-view semantics.

H02 checks string lengths and then calls `QtPrivate::equalStrings`. H03 checks list lengths, returns true when the list data pointers are identical, and otherwise compares each corresponding string length and calls `QtPrivate::equalStrings`. In F04, a false result from H02 or H03 causes the corresponding property signal call. The helper bodies are byte-verified. Other container append, copy, and cleanup functions called by H01 remain outside scope.

### Properties and options

F12 has a path with numeric parameter 2 equal to `1`. Numeric selector 0 copies four bytes from `this+0x10`. Selector 1 copies the `QString` at `this+0x18`. Selector 2 copies the three 8-byte slots at `this+0x30`, `+0x38`, and `+0x40`. Selector 3 copies the slots at `this+0x48`, `+0x50`, and `+0x58`. The metadata/string range contains the original labels `index`, `name`, `extensions`, and `globs`. The likely selector-to-label order is 0 through 3 in that order. This packet does not decode the complete Qt metadata object to prove that name mapping.

When numeric parameter 2 equals `2` and parameter 3 equals `0`, F12 loads an input integer and tail-jumps to F03. LLVM disassembly records this jump at `0x18000169d`. Ghidra reports it as a terminal call and says that the reason for its flow model is unknown. The raw listing warning is preserved in the source dossier.

When numeric parameter 2 equals `5`, F12 compares the supplied function pointer with `indexChanged`, `nameChanged`, `extensionsChanged`, and `globsChanged`. It writes signal IDs 0, 1, 2, and 3 for those exact methods, respectively. The labels are the exact exported names listed in the source map.

F06 returns an empty list if the options pointer at `this+0x60` is null. Otherwise, it calls the external `QT6GUI.DLL::QFileDialogOptions::nameFilters` and copies its list value. F05 also checks the options pointer. With no options, it constructs an empty `QString`. With options, it calls the same external routine and copies an item only on its widened unsigned index-versus-length branch. The fallback is a default-constructed `QString`. F07 copies the two `QSharedPointer` slots at `this+0x60` and `this+0x68` and updates the reference counters in its return path.

F08 stores the incoming shared-pointer fields at `this+0x60` and `this+0x68`. It updates reference counters and may call a stored deleter indirectly. Its captured body contains no direct call to F04 or to `QMetaObject::activate`. Ghidra reports the warning `/* WARNING: Function: _guard_dispatch_icall replaced with injection: guard_dispatch_icall */`. It also reports a terminal call at `0x1800031ee` to a `free` thunk and leaves the reason for the terminal flow unresolved. These observations do not establish what other callers do after changing the options.

## Inferences and unknowns

The class name and metadata strings alone do not establish UI behavior. This report records only the captured native paths. The exact mapping from numeric property selector values to the four property strings is likely based on their order, but the Qt metadata structure was not decoded.

The imported methods are call boundaries. This packet does not establish their implementation, ABI details, null-string behavior, delimiter-search behavior, split flags, list semantics, signal delivery, or Windows runtime behavior. It preserves the Ghidra labels in [the call-boundary inventory](SOURCE-MAP.json). Ghidra pseudocode and assembly are analysis views. They are not original C++ source.

The final Ghidra capture contains a terminal-flow warning at `0x18000169d` to F03. LLVM shows a relative jump to F03 at that address. The captured setter branch is clear. The reason Ghidra modeled the flow as terminal is unknown. The F08 indirect deleter and `free` thunk flow warnings also remain unresolved.

The report does not claim full DLL coverage, feature completion, a C++, Rust, or QML implementation, QML property registration, user-visible file filtering, Windows parity, or DJI Studio behavior outside these static bodies.

## Validation

The final verifier passed these checks against the pinned original file:

- It independently parsed the PE32+ header and all 24 exports. Its export set matches `llvm-objdump -p` version 22.1.8.
- It compared every byte in 20 complete function bodies with the original file. The bodies total 5,793 bytes. The local capture packet also records exact equality for all 20 separate procedure pseudocode and dossier pseudocode pairs. The portable verifier does not recompute those text comparisons because the raw text stays local.
- It compared a 1,088-byte read-only metadata and string span and 23 selected NUL-terminated strings with the source file.
- It parsed the 128-entry PE exception table and followed chained `UNWIND_INFO` records. Eight selected groups have contiguous spans equal to their complete Ghidra function bodies.
- It checked the `setIndex` 32-bit comparison, equality branch to the epilogue, changed-value store, RIP-relative `staticMetaObject` target, and indirect call bytes.

The separate assembly text did not need to equal the dossier assembly text. Attempt 01 failed only because its harness made that invalid comparison. The raw attempt remains local. Attempt 02 retained exact pseudocode equality and full byte checks. A first revision of the independent unwind parser followed only direct chain links. It failed on the `nameFilters` group. The final verifier follows nested links and passes. Both corrections are recorded in [VERIFICATION-HISTORY.json](VERIFICATION-HISTORY.json).

The original DLL remained unchanged. No vendor code ran. The raw analysis stays local. This is a static evidence handoff for future contract review. It is not an implementation or a feature claim.
