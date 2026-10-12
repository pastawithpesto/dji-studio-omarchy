# Selected R9 correction for the initial erratum

This packet corrects only the R9 wording for `methods.slot-1-dataflow`. It supersedes the unqualified statement that body `0x1800025b0` does not read R9 in the initial erratum REPORT.md and findings.json. The original erratum and reviews remain unchanged. Independent review of this new packet is pending. This is a selected correction, not whole research completion.

## Corrected static claim

At `0x180006ab0`, the slot routine executes `MOVZX R9D, byte ptr [RSP+0x8]`. It tail-jumps at `0x180006ab6` to `0x180001753`. That wrapper jumps to body `0x1800025b0`.

In the recorded body paths, no direct read of the incoming forwarded byte is established before R9 replacement. The body writes its own constant `0x7ffffffffffffff` to R9 at `0x180002613` and `0x1800026a4`. It reads R9 at `0x18000261d`, `0x18000262c`, `0x180002637` and `0x1800026ae`. These reads follow the local constant writes. The body therefore does read R9.

The first three reads use the constant written at `0x180002613`. The branch at `0x18000264a` can reach `0x1800026ae` with that value. The other shown route reloads the same constant at `0x1800026a4` after calls. This statement concerns direct decoded instructions in the recorded paths only. It does not infer transitive callee behavior or prove that the forwarded byte cannot affect external code. The byte meaning, semantic fourth argument, pointer validity, return type and runtime effects remain unresolved.

## Original evidence and correction history

Source: QuickLookHelper.dll, DJI Studio 1.0.0.30839, 128696 bytes, SHA-256 `c49e03bee7bfed1a1b9d6c982afdce43bb32c8dfe023ee29b55865243e59255b`.

The corrected original record is `reconstruction/quicklookhelper-rea640-20261011/initial-author-erratum/REPORT.md:31`, SHA-256 `12835129d9e5d15f67bf07951947a9b7a5080d70367a60dd53b5f3cce12ccebf`. Its findings.json is `0bad4f4ff9c4088ce8b735b3b75082436c4ea7c34d02f31d5b565c6b6ee693c8`. Its manifest is `71e8e36bb819c2ddbd716135933cab8531e788f696c595061c3220a5425bc2ee`. Original erratum author: `luna-a-2`. Initial methods author: `luna-b-3`. Initial exports author: `luna-a-2`. This new correction author is the separate author21 job, routing identity `sol-3`, GPT-6.1 Sol, High, Standard/default, Fast=false. The launch record supplies runtime attribution. The inherited git author configuration does not supply this attribution.

Independent erratum review2798 requested this correction. Its report is `088186c5f35e086bc038e813582d8ce9c5498e0533310d6d569b59a51552feff`. Its manifest is `50c568a718ca963e5558c25a3f510211ad202b1e0addd4954e37de8bf49b03f8`. The [Astra audit6118743343](https://github.com/pastawithpesto/dji-studio-omarchy/pull/21#issuecomment-6118743343) confirms the same remaining defect. ORIGINAL-PINS.json pins both records and the local complete audit.

Saved assembly Evidence IDs are `ev_731119bf0f58b0b89f048803c06797734ed17101e2ff485c09ae777bc268ca3c`, `ev_98a7117f8b480ce582071fc50df6c1dbe56dc26ca9e8c20f6634b49cd66bd07c` and `ev_c6556465643640c60275044c898e8a757da4dc4070ba4bbcc9015b0441bb6d63`. Saved provenance remains REA6.4.0 and Ghidra12.1.4. This packet reuses exact saved evidence and inspects original bytes offline. It does not claim new decompilation, live MCP access or current upstream freshness. No vendor code ran. No new DLL import occurred.

## Checks and preserved decisions

The full DLL hash matches. All17 original erratum code spans and3 data spans match exact bytes and hashes. All50 erratum manifest entries and70 erratum-review entries match. The three copied assembly records match the original source digest, Evidence IDs and file hashes. Independent local objdump of the slot, wrapper and 775-byte body confirms the selected instructions. CHECKS.json records exact commands. ORIGINAL-BYTE-WITNESSES.json retains the20 witnesses. These checks support the selected static correction only.

The six other initial corrections retain their bounded approvals. The initial erratum review remains historical `changes_requested`; this author does not upgrade its disposition. Configuration C1/C2 and hooks H1 approvals remain separate packets. This correction does not approve those contracts again. The original failed broad R9-token assertion remains in milestone-review/SUPPLEMENTAL-CHECKS.json, hash `51d7eb1c6a914af2ac1c1c6b1e24039c0bbf8885f0ae7eb365cfb5f5f36c981c`. No failed probe was removed.

The historical audit counts remain root3221/3221, exports27/27, methods416/419, initial independent review25/25, initial milestone19/19, erratum50/50 and erratum-review70/70. The three historical instruction-input mismatches are AGENTS.md, native/AGENTS.md and native/docs/RESEARCH.md. They remain a reproducibility limit. Only the erratum50/50 and erratum-review70/70 checks were repeated for this packet. The other counts are retained audit facts, not new whole-packet verification claims.

The original47-decision accounting remains35 approved,7 changes_requested and5 unresolved. The335 initial unresolved records remain unresolved historical accounting. This correction does not change those counts or establish complete internal or runtime coverage. UI, processing output, project compatibility, failure behavior, application implementation and Windows comparison remain separate unresolved gates.

## Source and next action

SOURCE-BASE.json records the owned worktree, preserved old PR head, appended current main, check time, ancestry and clean state before this correction. The selected packet manifest excludes its own hash. The exact published commit is recorded separately in HANDOFF.json and HEAD.json to avoid a self-reference.

The independent source reviewer must check the exact published candidate and packet hashes. A separate author25 verifier can then check the bounded PR21 milestone. This author does not review or verify PR21. Root controls acceptance and any protected integration. No merge, release, formal approval or commit status is created by this packet.
