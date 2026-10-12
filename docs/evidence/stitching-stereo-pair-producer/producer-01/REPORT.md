# `EisGetStereoPair` producer boundary and caller-side field source

Created 2026-10-12 19:53 UTC. This is a static evidence packet for PR48’s bounded producer task. No vendor DLL was loaded or run, no REA session was opened, and no project source or existing evidence packet was edited.

## Result

The exact decorated `EisGetStereoPair` import/export is present, but its implementation body is not recoverable from the pinned `dual_fisheye_video_eis_win.dll` file bytes. The export table maps it to ordinal 26, RVA `0x1474` (VA `0x180001474`). That RVA is in `.text`, whose `VirtualSize` is `0x2fc4e` and `RawDataSize` is zero. The PE therefore supplies no raw file offset or body bytes at the export location. This establishes a boundary in the original on-disk PE; it does not by itself establish how the function behaves in a loaded process.

Following the task’s fallback, the caller-side producer for the two previously unresolved values is now byte-pinned. In `VinceEditor.dll`, the function copies incoming `RCX` to `R15` at `0x18013cd75`, then writes the 32-bit literal `0x780` to `[R15+0x24]` and `[R15+0x28]` at `0x18013d187` and `0x18013d18f`. The complete saved disassembly has only those direct stores to these two `R15` offsets; its other matches are loads. The caller invokes helper `0x180137740` with `R15` at `0x18013d23f`. Its complete `.pdata` runtime-function range is RVA `[0x137740,0x1378a8)`. The helper body has no direct access to offsets `+0x24` or `+0x28`; its direct object offsets include `+0x6a8`, `+0x810`, `+0x814`, `+0x800`, and `+0x808`. Later, the caller loads dwords from `[R15+0x28]` and `[R15+0x24]` at `0x18013d424` and `0x18013d42e`. The earlier saved correction evidence independently pins that these loaded values are copied into the local `data_feed_stereo_pair` record before the update/feed calls.

`0x780` is reported as the literal value only. Its units and the meanings of the two record fields remain unknown. This proof establishes the direct caller-side stores, intervening helper’s complete byte range and direct accesses, and later loads; it does not prove absence of all indirect effects through the helper’s callees or other aliases.

## Pins and method

The source checkout used for the task plan is `/home/violence/Work/stitching-cache-verification-20261012/source`, branch `research/stitching-stereo-pair-producer-20261012`, HEAD `886e01f255877967c6cbd6b360e72f3dee4ec28e`, upstream `origin/main` `13357262099643200bffa435bce7a14528cf8d14`, clean. The plan file is `docs/tasks/stitching-stereo-pair-producer.md`. `origin/main` was fetched and verified during this audit. The new byte verifier checks the checkout HEAD, main SHA, and clean state before producing its JSON witness.

Original DJI Studio 1.0.0.30839 files:

- `VinceEditor.dll`, SHA-256 `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`.
- `dual_fisheye_video_eis_win.dll`, SHA-256 `e35f7397b9b6ad9b9e453ff01bc1f34e3ea9470bd6bc2a6b5bbdd637dac4e09a`.

`verify_producer_witnesses.py` parses the original PE headers, section table, export/import tables, exception table, and selected original `VinceEditor.dll` instruction bytes without mapping or executing either image. It checks the exact export and import name/IAT, the no-raw-backing condition, the `.pdata` bound, caller byte ranges, and saved-artifact hashes. Its output `PE-WITNESSES.json` includes the full bytes for the bounded helper body and selected caller ranges. `helper.objdump.txt` is a readable disassembly of the same `.pdata`-bounded body.

Reused saved evidence is pinned in `PE-WITNESSES.json`: the prior caller disassembly (`stitching-caller.objdump.txt`, SHA-256 `e2bb81db6589143ef68d36d68719f985199169cfb03df4300b32e5b4ff6c6ff3`), `STITCHING-CHECKS.json`, and the corrected caller-write report and manifest. The corrected report’s manifest SHA-256 is `c7743cbc0691959589b6ae2ec84042e88fbd8cca784ebc34bda4094a281a64b9`. Its ten record stores remain prior evidence, not a discovery in this packet.

## What remains open

The direct export implementation remains unresolved from original file bytes. To resolve that, the next useful query is a separately authorized, source-pinned capture of the loaded module’s executable mapping or an authentic unpacked build, followed by exact address-to-file/process-byte verification. If that evidence source is unavailable, continue only with a bounded static trace of the caller’s construction of the object passed in `RCX`, without assigning units or field semantics. Windows reference image comparison and full stitching parity are separate gates and were not rerun or established by this packet.
