# Original DJI QML resource bundle

`original.qrc` preserves exact resource aliases for the pinned original QML modules, including `qrc:/qml/Main.qml`, and all 211 loose `/app_qrc/...` resources in the reviewed original asset manifest. This contains 364 unique QML files, the original `Config` and `Controls` `qmldir` files, and 211 app resources.

Include `OriginalResources.cmake` from a Qt 6 CMake target context, call `dji_studio_attach_original_resources(<target>)`, and add `DJI_STUDIO_ORIGINAL_QML_IMPORT_PATH` to the QML engine's import paths. The import path is `qrc:/`, so original module aliases stay rooted at `/Controls` and `/Config`.

`source-provenance.json` pins each file to its source artifact, source hash, byte length, original qrc alias, and RCC record where applicable. Original payload bytes are not rewritten.

The exact original `/app_qrc/i18n_data.json` JSON catalog is included with its original alias and bytes. A reviewed static source inventory reports 1,980 keys and 16 exact locale-key spellings, including both `zh-Hant` and `zh_Hant`. This does not establish native lookup/fallback behavior or the displayed locale strings. No `.qm`/`.ts` catalog was found.

This is a resource-only increment. It does not supply the original executable's native QML modules, context objects, singleton registrations, or startup/show path. Compiling the qrc is not evidence that `Main.qml` instantiates, works, or matches the Windows UI.
