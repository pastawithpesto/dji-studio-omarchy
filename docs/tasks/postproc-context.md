# Recover bounded postproc-58 context and identity exports

Owner: @pastawithpesto

## Task

Recover a bounded static contract for public context construction and free policy, plus identity, version, and license exports, from the original `postproc-58.dll` in DJI Studio 1.0.0.30839. Preserve every exported name exactly.

The target is `/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/postproc-58.dll`. Its pinned SHA-256 is `fcb300de9e4702545991c4487e0ee90728090f22f3639c4bf6adc0bd4a03617b`. The file size is 99,512 bytes.

## Files

- `docs/tasks/postproc-context.md`
- `docs/evidence/postproc-context/**`

## Existing evidence

The initial local REA evidence search and the filtered evidence-bundle query returned no record matching the pinned target SHA-256. I used a private REA install under `tools/luna-postproc-rea-20261012`; the shared REA installation and peer sessions were left unchanged.

## Research performed

- Installed official REA `main` at `fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d` in the owned tool directory. The private MCP server reported version 6.4.0, MCP SDK 2.3.1, and aligned package/catalog identity.
- Compared LLVM `llvm-readobj` output with an independent PE parser. All ten names, ordinals, and RVAs matched; the parser mapped them to file offsets. Ghidra 12.1.4’s imported-name inventory contains every name once at the matching VA.
- Acquired and released the shared Ghidra lock nonblocking for two private sessions. The selected five code exports are JMP thunks, so the second capture covered only their direct implementation targets. The context initializer at `0x18000a970` remains outside scope.
- Matched all five exported thunk bodies and all five implementation bodies byte-for-byte to the original DLL using REA/Ghidra reads and an independent PE section mapper. The `postproc_ffversion` read also matched the source bytes. The source SHA-256 was unchanged before and after both captures.
- Published the bounded report, complete selected pseudocode/assembly and evidence IDs, source-byte map, tool pins, and offline validator in [`docs/evidence/postproc-context/`](../evidence/postproc-context/report.md). The offline validator passes against the pinned original DLL.
- The PR stays in draft while independent source and milestone reviews are pending.

## Completion check

The evidence packet must identify the pinned DLL by full SHA-256 and build. It must preserve exact exported names and pin every claim to addresses, tool evidence, and source-byte witnesses. LLVM and REA/Ghidra export inventories must agree. An independent offline check must verify any recovered constants, pointer policy, or identity values that the evidence supports.

This task covers static evidence for the named public exports. It does not establish whole-DLL coverage, runtime behavior, processing output, pixel or filter equivalence, or DJI Studio parity. Do not execute the vendor DLL. Keep uncertain types and unresolved behavior explicit.

## Source base at reservation

Repository: `pastawithpesto/dji-studio-omarchy`
Worktree: `/home/violence/Work/dji-postproc-research-20261012`
Branch: `research/postproc-context-20261012`
HEAD and freshly fetched `origin/main`: `54081edf52f23231500db222136eae0a681e6535`
Checked at: `2026-10-12T01:27:38-05:00`
Main ancestry: verified; main is the branch base.
Status: clean before this task-plan edit.

The task-only reservation is commit `727505e95e03e99ff4496e5a0a1129f5da7da52c`. Subsequent base updates were merged normally. The evidence edit began after fetching `ad90db13d7fff5745baa5ec84ff1b7c31a19ac35`, reviewing all open claims, and observing a successful claim watchdog on head `a756fdcbd17d3a4d53959110e976473bf0c94386` (run `38215252693`).
