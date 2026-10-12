Independent reviewer sol-2 completed instruction 2952. Author root remains separate. The bounded static facts are approved with the mandatory additive scope and count corrections. The original report is preserved. Its phrase “146 native body ranges” requires correction and is resolved by COUNT-CORRECTION. No other static contract defect was found.

| Sealed input | SHA-256 |
| --- | --- |
| REPORT.md | 99f9497af4012ebfbfe0c43dbce82006036813e62d0e575d26dd56ebb084cd13 |
| FINDINGS.json | 1ad1672ae85a6efa78fc38912a5a2913a00e3001e8c5655fd5602b8b81e572f6 |
| MANIFEST.json | a38866c0c54a9b78cf280ba4fe1dd1e2d8ce6e9d5f4f0ee07d7beac5294cf831 |
| SCOPE-CLARIFICATION.json | 188c6acf9a83a5eada1e0881a2052f32600d4f4989b46c1d2f2018a1c4f8f2b0 |
| COUNT-CORRECTION.json | 75e534acd7e51d0b5fa61dcb8fca8137aa55a0018a19cbe1f0c6eba6351b5d5a |

All 43 original hashes and 1,175 immutable manifest files match. Independent bounded PE parsing matches every export ordinal, exact name, RVA, forwarding target, section flag, directory and file offset. Fresh LLVM 22.1.8 and binutils output independently match all 2,960 forwarders. All 41 API-set files have zero code size and entry point, no executable or code sections, and no ordinary import, delay import, exception, TLS or CLR directories. These are shipped forwarding strings. External Windows implementation and loader resolution remain unresolved.

All four codecvt exports are data at 0x180003040, 0x180003048, 0x180003050 and 0x180003058. Each initial file-backed qword is zero. Exact decorated names and independent LLVM demangling are recorded. No conversion algorithm is exported. Initial zeros do not prove consumer runtime invariants. Entry 0x180001340 and internal 0x180001000 match the bounded lifecycle observations. External CRT and kernel calls remain unobserved.

All seven msvcp140_1 export machine contracts are approved separately in CONTRACT-CHECKS.json. Both default getters read 0x180005260. Their zero fallbacks are 0x180005000 and 0x180005008. Both setters exchange RCX with the shared qword and return the old value, with their own zero fallback. A new null RCX is stored. Direct resource getters return the exact three source objects. XCHG establishes an atomic machine exchange. It does not establish complete object lifetime or threading semantics.

The three qwords point to the exact four-slot tables at 0x180003240, 0x180003218 and 0x180003268. The first slots test DL bit 0 and conditionally route a size-8 deletion. Complete field types remain unresolved. Aligned allocation uses unsigned alignment <=16 for the malloc helper and >16 for the aligned helper. Unaligned allocation >16 calls the bad-allocation import. Successful helper returns preserve allocator RAX despite void pseudocode. Aligned payload deallocation uses the matching unsigned R9 threshold for free or aligned_free. Unaligned payload deallocation uses free. The null allocation slot calls the bad-allocation import. Its second operation is RET 0, encoded c20000. Equality writes only AL from pointer equality. Upper RAX bits are not defined by that sequence.

Both allocation helpers invoke _callnewh after a zero allocation result and retry on nonzero EAX. A zero handler result selects UINT64_MAX for the bad-array-new-length construction route and other sizes for the bad-allocation route. Original constructor stores, exact messages, raw metadata, RTTI names, branch instructions and IAT thunks independently support these identities. Both routes call _CxxThrowException. External allocation, handler, throw and unwind behavior remains unresolved. No complete exception layout, ownership rule or safe Rust error contract is approved.

| Capture | Procedures | Inclusive ranges | Bytes | Independent instruction witnesses |
| --- | ---: | ---: | ---: | ---: |
| msvcp140_codecvt_ids.dll | 53 | 55 | 3,034 | 833 |
| msvcp140_1.dll | 93 | 97 | 3,949 | 1,083 |
| Total | 146 | 152 | 6,983 | 1,916 |

Every body range matches original source bytes and its exact saved Evidence ID. All dossier, separate pseudocode, assembly and byte records agree with the sealed bundles. BODY-CHECKS.json lists each approved capture. Each independent binutils instruction witness also maps back to original bytes. Full procedure capture does not approve every CRT path or prove provider boundaries cover all executable behavior.

Saved evidence remains pinned to REA upstream a1b5d51a8dfb7fff6272d91270c16b95555c2643, package/server 6.4.0 and Ghidra 12.1.4. This review used saved evidence offline. It opened no provider session and made no new decompilation or live-server claim. The codecvt snapshot contains 220 records. All are exact members of the final 262-record bundle. The 42 additional records are inspect_pe_resources captures. The msvcp140_1 snapshot and bundle contain the same 377 records. Successful close/export receipts, snapshot hashes and DATA-PROBE-CORRECTION remain preserved. Provider terminal-call/no-return observations, unreachable-block warnings, guard-dispatch substitutions and uncertain signatures remain in the complete type and limit ledgers.

The selection contains the 41 API-set family members and the two smallest non-api files. It is not the first 43 files by size. The separately pinned clarification agrees with the saved 242-file size order. The count correction agrees with all 152 distinct ranges. The raw original range-count wording has a changes_requested disposition with that correction as its resolution. Full CRT/runtime semantics, unresolved types and ABI, Rust reconstruction, Windows behavior, and whole-app/media/UI/project parity have unresolved dispositions. REVIEW.json records every claim. FORWARDING-ROUTE-DISPOSITIONS.json records each of the 2,960 routes.

The reviewer wrote only this new independent-review directory. No author script, provider import, vendor execution, application edit, configuration edit, peer process action, merge or release occurred. Two verifier assumptions failed before correction. Their scripts and stderr remain preserved. A navigation probe used a guessed raw offset; it was rejected. Final metadata reads use independently parsed source headers. FAILURE-AND-CORRECTION-LEDGER.json records these limits.

The current PR32 claim and all open claims were read. The claims watchdog succeeded at 2026-10-12T03:59:56Z. Source was fetched again at final review. Repository is https://github.com/pastawithpesto/dji-studio-omarchy.git. Author worktree /home/violence/Projects/dji-studio-omarchy/source-worktrees/root-smallest-dlls-20261012 has branch work/root-smallest-dlls-20261012 and HEAD 81f2f120a701931dc368bf63687a79647f102507. Fresh main 2ff7205a6019474e83662edb7bf18a123dcc31cd is an ancestor. This worktree is clean. The check time is 2026-10-12T04:22:52.632000+00:00. The canonical native worktree remains on main at 91f1fd620a7a0aea74db49a03be240ee59681401. Fresh main is not its ancestor. Its peer changes remain preserved. SOURCE-TUPLES.json records both tuples exactly. This is evidence review, not approval of source integration or publication.

CONTINUATION-STATE.json is complete for this packet. The next gate belongs to the owner: request milestone verification of this exact review before selected evidence publication. No further reviewer task is assigned. Do not repeat this completed packet.
