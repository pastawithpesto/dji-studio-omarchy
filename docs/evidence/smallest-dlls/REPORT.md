# Smallest original DLLs

Root recovered the static export surfaces of43 original DLLs from DJI Studio1.0.0.30839. This packet contains41 API-set forwarding libraries and the smallest two remaining non-api libraries. Independent evidence review is pending.

## Exact forwarding routes

All41 API-set files have zero code size and entry point, no executable sections and no ordinary/delay import, exception, TLS or CLR directories. Every2960 named EAT slot contains a forwarder inside the export directory. The independent LLVM and binutils results match every ordinal, exact name and forwarding target. These files contain routing data; external Windows target implementations and loader resolution remain separate obligations. Full routes, file offsets and hashes are in SELECTED-PE-MAPS.json and FINDINGS.json. REA PE resource Evidence for every file is in RESOURCE-INDEX.json.

## msvcp140_codecvt_ids.dll

Source21544bytes, SHA2569f05310a2330ee37b2f814c1d6ef40be553cc5bfd3f301b84dc221160f687f87. Four named data exports occupy0x180003040,+3048,+3050,+3058. Their eight initial file-backed bytes are all zero. Original decorated names remain exact; independent LLVM demangling identifies locale::id objects for codecvt of char16_t/char32_t and char/char8_t. This DLL does not export conversion functions. Initial zero data does not prove those IDs remain zero during consumer use.

REA captured all53 native provider procedures and3034 body bytes. Lifecycle entry0x180001340 and internal attach/detach code use the recorded CRT and kernel32 boundaries. Internal0x180001000 checks DisableThreadLibraryCalls only for reason1 and reports its failure. No vendor execution or lifetime parity is observed. All native raw dossiers, separate pseudocode/assembly and complete inclusive range witnesses are retained.

## msvcp140_1.dll

Source25136bytes, SHA2569d6a0264a41ef8b3e758cfcced8ab3270c76211b75af6981c991b50cb00f2a85. Its seven original export names and byte-backed machine contracts are in FINDINGS.json. All93 native provider procedures and3949 body bytes are captured.

Aligned and unaligned getters read the same qword0x180005260. Nonzero defaults are returned unchanged. For zero, aligned returns0x180005000 and unaligned0x180005008. Both setters exchange RCX with that shared qword using XCHG and return the old value with their own zero fallback. A new null value is stored. The aligned/unaligned new-delete getters return those two objects directly. null_memory_resource returns0x180005010.

The three source objects point to four-entry tables at0x180003240,0x180003218 and0x180003268. Exact table pointers are retained in DATA-STRUCTURES.json and independently readable original data disassembly. The aligned allocation route chooses malloc for unsigned alignment<=16 and aligned_malloc above16. The unaligned allocation route calls the bad-allocation import for alignment>16. Matching payload deallocation routes use free or aligned_free. The null table allocation slot calls the bad-allocation import; its second operation is a single RET. Shared comparison assigns only AL from pointer equality. Pseudocode that labels successful allocation helpers void is not a recovered return contract: original instructions preserve the allocation result in RAX.

Both allocation helpers retry after a nonzero _callnewh result. After a zero handler result, sizeUINT64_MAX selects the bad-array-new-length construction route; other sizes select bad-allocation construction. Both routes call _CxxThrowException. External allocator, handler and throw behavior remains unobserved. Do not claim a full C++ ABI or fabricate safe Rust errors from these calls.

## Provenance and limits

Official upstreama1b5d51a8dfb7fff6272d91270c16b95555c2643 was freshly cloned and built in tools/root-smallest-rea-20261012. REA reports6.4.0; Ghidra12.1.4 used a768M owned heap. Analysis acquired the shared exclusive import lock. Both evidence bundles and snapshots saved and owned sessions closed successfully. Original sources remain unchanged. SDK2.3.1 callTool timeout used the documented second argument. Timings record individual operations without any benchmark or speedup claim.

All146 native body ranges match original source bytes. Full capture does not approve every CRT path or unresolved call. Terminal-call/no-return observations retain their actual provider limits. DATA-PROBE-CORRECTION.json preserves an unused-loop KeyError and the bounded completion of the missing data packet. The original successful byte capture was unaffected. Windows runtime, reconstruction, integration, media, UI and project equivalence remain pending.
