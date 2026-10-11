# Original DJI QML resource bundle

`original.qrc` preserves exact resource aliases for the pinned original QML modules, including `qrc:/qml/Main.qml`, and all 210 loose `/app_qrc/...` assets in the reviewed asset manifest except the separate localization payload. This contains 364 unique QML files and the original `Config` and `Controls` `qmldir` files.

Include `OriginalResources.cmake` from a Qt 6 CMake target context, call `dji_studio_attach_original_resources(<target>)`, and add `DJI_STUDIO_ORIGINAL_QML_IMPORT_PATH` to the QML engine's import paths. The import path is `qrc:/`, so original module aliases stay rooted at `/Controls` and `/Config`.

`source-provenance.json` pins each file to its source artifact, source hash, byte length, original qrc alias, and RCC record where available. Original payload bytes are not rewritten.

No reviewed `.qm`/`.ts` catalog or translation mapping corpus was found. `/app_qrc/i18n_data.json` is therefore omitted; QML `qsTr` source keys remain intact, while rendered locale strings remain unresolved.

This is a resource-only increment. It does not supply the original executable's native QML modules, context objects, singleton registrations, or startup/show path. Compiling the qrc is not evidence that `Main.qml` instantiates, works, or matches the Windows UI.
