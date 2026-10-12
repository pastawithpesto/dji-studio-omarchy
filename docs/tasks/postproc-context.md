# Recover bounded postproc-58 context and identity exports

Owner: @pastawithpesto

## Task

Recover a bounded static contract for public context construction and free policy, plus identity, version, and license exports, from the original `postproc-58.dll` in DJI Studio 1.0.0.30839. Preserve every exported name exactly.

The target is `/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/postproc-58.dll`. Its pinned SHA-256 is `fcb300de9e4702545991c4487e0ee90728090f22f3639c4bf6adc0bd4a03617b`. The file size is 99,512 bytes.

## Files

- `docs/tasks/postproc-context.md`
- `docs/evidence/postproc-context/**`

## Existing evidence

The coordinator's initial inventory found no matching saved target claim. I will inspect compatible local evidence before a new import. I will preserve the shared REA installation and all peer analysis sessions.

## Next steps

1. Fetch the official REA default branch and update only the owned installation.
2. Record the REA commit, package version, running MCP version, Ghidra version, settings, binary hash, and source locations.
3. Inspect the current PE export table with LLVM and compare the names independently with the REA/Ghidra view.
4. Reuse matching saved evidence. If none exists, request and acquire the shared Ghidra import lock before importing the pinned DLL.
5. Decompile the bounded exports and only the small helpers needed to establish their contracts. Check the pseudocode against assembly and original source bytes.
6. Record a source map, validation results, evidence provenance, and unresolved limits under `docs/evidence/postproc-context/`.

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
