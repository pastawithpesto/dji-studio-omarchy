# Atomic timeout contract review

Reviewer: /root/sol61_atomic_contract. This review is independent of the DSH
researcher and the Zcode Rust author. The reviewer made no application source
edits. The DSH packet and the Rust candidate are pending separate review.

The existing bounded static contract passes original-byte review. It can support
two pure Rust functions. This result does not approve a Rust candidate or establish
Windows execution equivalence.

## Original source and evidence

The original build is DJI Studio 1.0.0.30839. The file is
`/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/msvcp140_atomic_wait.dll`.
Its size is 57,376 bytes. Its SHA-256 is
`ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.

The independent PE parser in `check-original.py` reads the original file. It
checks each named export, ordinal, RVA, raw section offset, complete function
body, and named import target. `original-byte-check.json` records the results.
`original-objdump.asm` records GNU objdump 2.47 disassembly from the same file.
All nine hashes in the public packet manifest match their files.
Both saved provider byte witnesses also match the complete original bodies.
They are `ev_48a7b709ac9087965e997936bb23d572d78a5b9d85300eae635fb3105e01a9a0`
and `ev_53de07bd265eccc7c5842600bb699a4f8dde5b9e4027d21b71b2f7a7927aa679`.
This check verifies saved provider witnesses against the original file. It is not
a read from a newly loaded Ghidra image.

| Original export | Ordinal | VA | Offset | Bytes | Body SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `__std_atomic_wait_get_deadline` | 11 | `0x1800015c0` | `0x9c0` | 33 | `91a621460251e107081a5c4abe58a32f74745cd2b6d93cc8fca49a9dca158b88` |
| `__std_atomic_wait_get_remaining_timeout` | 12 | `0x1800015f0` | `0x9f0` | 56 | `2090187ba92fcec6d04afdfdf1e278feaeb834ad6bef76ad6b7f1c62370516ad` |

The calls at `0x1800015d2` and `0x180001604` both resolve through the PE import
slot at `0x1800050d0` to `KERNEL32.dll!GetTickCount64`.

The existing Ghidra dossier evidence IDs are
`ev_209bd7420d4f44455daadb705efb3e8627bb253a7456ffc5aa8f36a97af1547f`
and `ev_57a5b4512cdb28567a23bcdf9bb783737250e6eb651b1f4a038c376ce4e15817`.
They were produced by REA commit `fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d`,
package 6.4.0, and Ghidra 12.1.4. This review preserves those identities.

## Supported Rust contract

Keep both exact export names as Rust function names. Both names are valid Rust
identifiers. Accept an explicit clock with type `FnMut() -> u64`. Represent the
argument and observed RAX result as `u64` bits. These types form an independent
Rust API. They do not claim the original formal C++ types or a Windows ABI.

For `__std_atomic_wait_get_deadline`, an input of `u64::MAX` returns `u64::MAX`
and makes zero clock calls. Every other input makes exactly one clock call.
The result is the clock value plus the input modulo 2^64. Use wrapping addition.
Keep finite additions that produce `u64::MAX` or zero.

For `__std_atomic_wait_get_remaining_timeout`, an input of `u64::MAX` returns
`0x00000000ffffffff` and makes zero clock calls. Every other input makes exactly
one clock call. Use an unsigned comparison. Return zero if the clock value is
equal to or greater than the deadline. Otherwise return the smaller of
`deadline - clock` and `0x337f9800` as zero-extended `u64` bits.

The instructions establish these rules. The deadline sentinel branch skips
CALL and retains the all-ones RAX value. ADD has no carry check. The remaining
sentinel branch writes EAX. The comparison uses JB. The cap comparison uses JA.
All remaining-timeout return paths write EAX and thus zero-extend into RAX.

An explicit clock makes the arithmetic meaningful without inventing a Linux
clock mapping. A later caller must supply the intended tick domain. This bounded
module adds no system clock, wait loop, thread wakeup, or runtime integration.

## Required candidate checks

Use the eleven existing static reference vectors. Also check zero clock calls
for each sentinel and exactly one clock call for every finite path. Include
unsigned high-bit values to distinguish unsigned comparison from signed
comparison. Include a finite zero deadline with a large clock value. Test the
cap at one below, equal, and one above. Test finite addition to the sentinel
and finite addition through zero. Use the static original instructions as the
oracle. A synthetic pass does not establish vendor execution parity.

## Latest tool inspection and snapshot limits

The owned stdio MCP server uses
`/home/violence/Work/zcode-rea-tools-20261012/rea/scripts/rea.mjs`.
The source commit is `7ae3c50a9d49c480035855de9fcc4484befacd92`.
`Client.getServerVersion()` reports `rea` version 6.4.0. The package is 6.4.0.
The server path alignment check passes. The server reports no build commit;
the local source commit and entry/dist hashes are recorded separately in
`rea-owned-provenance.json`.

The old snapshot is
`/home/violence/Projects/dji-studio-omarchy/reconstruction/luna-atomic-wait-20261012/analysis.snapshot.json`.
Its SHA-256 is `9c03192eed52b16b3159ffbbde1cedb3749fe3e2814bbff038dd998e1189bea3`.
The latest parser authenticates both saved `analyze_function` entries and eight
evidence records. Its profile digest is
`1974e8b97d53c06a1572c109c6497629fdd8513abc4625ca30722f223f0b47bb`.
This proves offline schema and integrity compatibility. A live profile match
and newly loaded image remain unverified at this checkpoint.

The latest `open_binary` schema accepts `snapshot_path`. Source inspection shows
that opening calls Ghidra health before loading the saved analysis snapshot.
Ghidra health starts a new image import and default analysis. The reviewer
reported this boundary before opening. The initial owned MCP session performed
identity and schema inspection only. It exported its evidence before close.

## Source state and limits

At 2026-10-12T14:45:02Z, remote main was
`8b147cadd1b92ff52b30cde995429cb04f85eb17`. It was an ancestor of workflow
HEAD `d362f754d84e4b7a1ec6bde75cd09b2247fad3cd` on
`tools/headless-agent-workflow-20261012`. That root-owned worktree had active
workflow edits. This reviewer preserved them. PR 45 reserves the proposed Rust
scope separately. No formal prototype, whole-DLL, wait-loop,
wakeup, Linux-clock, Windows-ABI, camera, GUI, or application parity is added
to the bounded approval.
