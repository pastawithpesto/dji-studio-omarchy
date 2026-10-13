# Atomic wait timeout contract, bounded research findings

Task: read-only research on two exports of `msvcp140_atomic_wait.dll` from
DJI Studio 1.0.0.30839. Owner working directory:
`/home/violence/Work/dji-headless-evidence-20261012/dsh`. No source file, peer
session, repository branch or vendor binary was changed.

## 1. Pinned source

| Item | Value |
| --- | --- |
| File | `/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/msvcp140_atomic_wait.dll` |
| Size | 57376 bytes |
| SHA-256 observed | `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae` |
| SHA-256 pinned | `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae` |
| Format | PE32+, machine `0x8664` (AMD64), image base `0x180000000` |
| Sources | `docs/evidence/atomic-wait-timeouts/source-map.json`, `manifest.json` |

The hashes match. The saved snapshot binds the same target SHA-256.

Source base check of the instruction checkout
`/home/violence/Work/dji-headless-agent-workflow-20261012` at
2026-10-12T14:52Z:

* Task-start main `8b147cadd1b92ff52b30cde995429cb04f85eb17` is an ancestor of
  the current HEAD `d362f754d84e4b7a1ec6bde75cd09b2247fad3cd` ("Reserve
  persistent headless agent workflow").
* Another agent owns that checkout. It has uncommitted changes to `AGENTS.md`,
  `docs/tasks/headless-agent-workflow.md` and new headless agent files.
* I did not change that checkout. My offline import of the peer
  `reference_model.py` created one `__pycache__` byproduct. I removed it. The
  saved generator now sets `sys.dont_write_bytecode` and leaves no byproduct.

## 2. Exact body evidence

The two bodies are contiguous and non-overlapping. My own offline PE parse and
two independent disassemblers agree with the saved Ghidra text.

| Export | Ordinal | RVA | VA | File offset | Length | Body SHA-256 |
| --- | --- | --- | --- | --- | --- | --- |
| `__std_atomic_wait_get_deadline` | 11 | `0x15c0` | `0x1800015c0` | `0x9c0` | 33 | `91a621460251e107081a5c4abe58a32f74745cd2b6d93cc8fca49a9dca158b88` |
| `__std_atomic_wait_get_remaining_timeout` | 12 | `0x15f0` | `0x1800015f0` | `0x9f0` | 56 | `2090187ba92fcec6d04afdfdf1e278feaeb834ad6bef76ad6b7f1c62370516ad` |

Body bytes:

```text
deadline   40534883ec204883c8ff488bd9483bc87409ff15f83a00004803c34883c4205bc3
remaining  40534883ec20488bd94883f9ff750583c8ffeb1eff15c63a0000483bc3720433c0eb0f482bd8b800987f33483bd877028bc34883c4205bc3
```

Time source: `KERNEL32.dll!GetTickCount64` at IAT RVA `0x50d0`, VA
`0x1800050d0`. Call sites: `0x1800015d2` and `0x180001604`. Both indirect calls
resolve to this single import slot by `FF 15 disp32` displacement.

Independent structural checks from my own parse:

* `.pdata` RUNTIME_FUNCTION entries give the same extents:
  `0x15c0..0x15e1` (33 bytes) and `0x15f0..0x1628` (56 bytes).
* The export address table holds both RVAs at `0x18000531d` and `0x180005322`.
* `.rdata` at `0x180006660` and `0x180006664` holds a table of 4-byte RVAs.
  Adjacent entries name `__std_atomic_wait_direct`, `__std_atomic_wait_indirect`,
  `__std_atomic_notify_one_direct` and other exports. This is an observation of a
  registration table. It is not caller evidence.

GNU objdump 2.47 and LLVM objdump independently decode every instruction. Both
outputs match the saved Ghidra assembly line by line. The saved packet files are
byte-identical to the snapshot Evidence text. The packet manifest hashes all
match.

## 3. Recovered machine behavior

These facts come from the body bytes and the disassembly only.

### 3.1 `__std_atomic_wait_get_deadline`, 33 bytes at `0x1800015c0`

| Property | Observation |
| --- | --- |
| Input width | 64 bits, read from `RCX` (`MOV RBX, RCX` at `0x1800015ca`) |
| Output width | 64 bits, `RAX` |
| Sentinel | `OR RAX, -1` at `0x1800015c6`; `CMP RCX, RAX`; `JZ 0x1800015db` at `0x1800015d0` |
| Sentinel result | `RAX = 0xffffffffffffffff` |
| Clock calls | 0 on the sentinel path, 1 on every other path (single `CALL` at `0x1800015d2`) |
| Arithmetic | `ADD RAX, RBX` at `0x1800015d8`. This is 64-bit addition modulo 2^64 |
| Carry and saturation | None. No flag test follows the add. No branch follows the add |
| Exit | Single epilogue at `0x1800015db` and `RET` at `0x1800015e0` |

A finite input can collide with the sentinel. Example: input `10` plus a clock
value `0xfffffffffffffff5` returns `0xffffffffffffffff`. A finite input can also
wrap to zero. Example: input `11` plus the same clock value returns `0`.

### 3.2 `__std_atomic_wait_get_remaining_timeout`, 56 bytes at `0x1800015f0`

| Property | Observation |
| --- | --- |
| Input width | 64 bits, read from `RCX` (`MOV RBX, RCX` at `0x1800015f6`) |
| Output width | 32 bits on every path. Each path writes `EAX`, and an `EAX` write zero-extends into `RAX` |
| Sentinel | `CMP RCX, -1`; `JNZ 0x180001604` at `0x1800015fd` |
| Sentinel result | `OR EAX, 0xffffffff` at `0x1800015ff` gives `RAX = 0x00000000ffffffff` |
| Sentinel clock calls | 0 |
| Clock calls | 1 on every other path (single `CALL` at `0x180001604`) |
| Expired or equal deadline | `CMP RAX, RBX`; `JC 0x180001613` at `0x18000160d`. `JC` is an unsigned "below" test. When the clock value is equal to or above the input, `XOR EAX, EAX` at `0x18000160f` returns 0 |
| Difference | `SUB RBX, RAX` at `0x180001613`. The `JC` branch guarantees clock below input, so no underflow is reachable |
| Cap | `MOV EAX, 0x337f9800` at `0x180001616` gives `RAX = 0x00000000337f9800`. `0x337f9800` is 864000000 |
| Clamp compare | `CMP RBX, RAX`; `JA 0x180001622` at `0x18000161e`. `JA` is an unsigned "above" test |
| Clamp result | A difference above the cap returns `0x337f9800`. Equality falls through to `MOV EAX, EBX` at `0x180001620` and also returns `0x337f9800` |
| Return value | `MOV EAX, EBX` at `0x180001620`. The guard proves the difference is at most `0x337f9800`, so the 32-bit write is exact on this path |
| Exit | Single epilogue at `0x180001622` and `RET` at `0x180001627` |

Bit-level consequence: a caller that compares the returned `RAX` with
`0xffffffffffffffff` never sees that value from this body. The sentinel path
returns `0x00000000ffffffff`.

## 4. Pure Rust contract

The clock is an explicit input. The module must not guess a Linux clock. No
`Instant`, `SystemTime`, `CLOCK_MONOTONIC` or uptime substitute belongs in this
contract. The unit, epoch and suspend behavior of the number belong to the
caller, because the DLL bytes do not establish them.

```rust
#![allow(non_snake_case)]

/// The largest value the remaining-timeout body can return before the clamp.
/// Observed as the immediate of `MOV EAX, 0x337f9800` at 0x180001616.
pub const MAX_REMAINING_TIMEOUT: u32 = 0x337F_9800;

/// Explicit clock dependency. The DLL reads its single imported time source
/// at most once per invocation.
pub trait TickCount64Source {
    /// Returns the raw 64-bit count. The caller owns the unit and the epoch.
    fn get_tick_count64(&mut self) -> u64;
}

/// Machine body at 0x1800015c0, 33 bytes.
pub fn __std_atomic_wait_get_deadline<C: TickCount64Source>(
    timeout: u64,
    clock: &mut C,
) -> u64 {
    if timeout == u64::MAX {
        return u64::MAX; // sentinel, no clock read
    }
    clock.get_tick_count64().wrapping_add(timeout) // modulo 2^64, no saturation
}

/// Machine body at 0x1800015f0, 56 bytes.
pub fn __std_atomic_wait_get_remaining_timeout<C: TickCount64Source>(
    deadline: u64,
    clock: &mut C,
) -> u32 {
    if deadline == u64::MAX {
        return u32::MAX; // 0xffffffff, no clock read
    }
    let tick = clock.get_tick_count64();
    if tick >= deadline {
        return 0; // unsigned comparison, equal or past
    }
    let remaining = deadline - tick; // exact, the branch proves tick < deadline
    if remaining > MAX_REMAINING_TIMEOUT as u64 {
        return MAX_REMAINING_TIMEOUT; // unsigned clamp
    }
    debug_assert!(remaining <= MAX_REMAINING_TIMEOUT as u64);
    remaining as u32 // truncating cast; the guard makes it the identity here
}
```

Contract points:

* Input widths are 64 bits for both functions.
* The first function returns 64 bits. The second returns 32 bits.
* The sentinel early return happens before any clock read in both functions.
* Each function reads the clock zero times or one time per invocation.
* The addition wraps modulo 2^64. A carry check would be a behavior change.
* Both comparisons in the second function are unsigned.
* The clamp cap is `0x337f9800` (864000000). The value is not named by the
  vendor. `MAX_REMAINING_TIMEOUT` is a neutral Rust label, not an original name.
* `remaining as u32` truncates. On the reachable path the value is at most the
  cap, so the cast is exact. The machine performs the same low-32-bit write.
* The exact export names are preserved. Return type mapping to `u64` and `u32`
  is a Rust adaptation of observed machine widths, not a recovered C++ type.

## 5. REA evidence and tool identity

Owned namespace: `rea_latest`, stdio transport. Command:
`/home/violence/.local/share/mise/installs/node/26.9.0/bin/node
/home/violence/Work/zcode-rea-tools-20261012/rea/scripts/rea.mjs mcp`.

| Item | Observed value |
| --- | --- |
| REA upstream commit | `7ae3c50a9d49c480035855de9fcc4484befacd92` (matches task pin) |
| Package | `rea-agents` 6.4.0 |
| Running server | `rea` 6.4.0 |
| Alignment | `aligned`, no reasons, no remediation |
| Node | v26.9.0 |
| Entry SHA-256 | `25ef01e0ed78abf3786cc44684f751ac0d9c45897be210c6af2e26c7aa656eee` |
| `dist/mcp/main.js` SHA-256 | `917fbacf534a7cbd2c0c4bcb65efe8adc8db3bc3924b4e819f017f9e7e3b0eb1` |
| Tools advertised | 182 |
| Session open after probe | `false` |
| Read-only tools | `binary_session`, `get_evidence_bundle`, `list_unknowns`, `verify_unknown_resolution`, `evaluate_reconstruction_coverage`, `frida_session_status` |

Local check tool versions: GNU objdump 2.47, LLVM objdump 22.1.8, Python 3.14.7,
Rust 1.98.1 (edition 2024), Node 26.9.0.

I used the identity query `binary_session` with `expected_package_version` and
`expected_server_path`. That query is marked `readOnlyHint: true`. It opened no
target.

Capability result on this host: the Ghidra provider candidate is `unavailable`
with code `not_configured`. The reason is "Set GHIDRA_INSTALL_DIR to an extracted
Ghidra 12.1.x release directory." The diagnostics report no `analyzeHeadless`, no
matching native decompiler and no Java runtime. The `official-proxy` surface
(32 operations, including `read_bytes`, `procedure_assembly`,
`procedure_pseudo_code`) and the `enhanced` surface (11 operations, including
`analyze_function`) are both `available: false` with reason `target_required`.

Consequence: this namespace cannot perform a new decompilation of the two
exports. An installed Ghidra directory elsewhere on the host is not proof of a
working analysis path in this namespace.

Offline saved-snapshot inspection used the same pinned REA code:

* Parser: `dist/domain/analysisSnapshot.js` of REA 6.4.0.
* Snapshot: `/home/violence/Projects/dji-studio-omarchy/reconstruction/luna-atomic-wait-20261012/analysis.snapshot.json`
* Snapshot SHA-256: `9c03192eed52b16b3159ffbbde1cedb3749fe3e2814bbff038dd998e1189bea3`
* Result: parse accepted. Target SHA-256 matches the pinned source.
* Provider binding: Ghidra 12.1.4, analysis-profile digest
  `1974e8b97d53c06a1572c109c6497629fdd8513abc4625ca30722f223f0b47bb`.
* Entries: `analyze_function` at `0x1800015f0` and `0x1800015c0`.
* Evidence records: 8.
* Reused evidence IDs: `ev_209bd7420d4f44455daadb705efb3e8627bb253a7456ffc5aa8f36a97af1547f`,
  `ev_57a5b4512cdb28567a23bcdf9bb783737250e6eb651b1f4a038c376ce4e15817`,
  `ev_7022277816ecc376228177154e8a556f5508328aa8538be7211296d4788627a7`,
  `ev_546496283496dc3c2ed6dfe17638d66e448ba2c1facd44637d0ff55564a4d4a4`,
  `ev_f5a8e55e4c33fc4114a120d66271e76d2171ec4c66b1b1083d0b8446f372df95`,
  `ev_cfa7bf064740881669fa11b832625e8548c6536b3231b5047d4850b89907d00c`.

Snapshot facts:

* Both records have authority `shipped-artifact` and confidence `observed`.
* Ghidra signature strings are `longlong __fastcall
  __std_atomic_wait_get_deadline(longlong param_1)` and `ulonglong __fastcall
  __std_atomic_wait_get_remaining_timeout(ulonglong param_1)`. The snapshot
  marks these as recovered decompiler artifacts, not source declarations.
* Both `callers` arrays are empty. Incoming references are DATA only, from the
  export table, the `.rdata` registration table and `.pdata`. No CALL edge
  reaches either body in the saved dossier.
* Both callee lists hold only `KERNEL32.DLL::GetTickCount64`.
* Value-flow data is complete, not truncated. Known omitted edges and omitted
  inputs are 0.
* The dossier limitation text says that unresolved targetless flows remain
  unknown. It also says that pseudocode and assembly are provider-specific text
  and are not cross-provider invariants.

## 6. Grant boundary

No import grant exists for this namespace. The root scope message
`headless-atomic-wait-20261012` (peer bus id 3726) states: "DSH reader has
independent owned namespace and no import grant." The same message gives one
owned saved-snapshot read/open to the peer identity `sol61-atomic-contract`
after a nonblocking lock acquisition, and it forbids a new import when a restore
suffices.

Operations that need a grant, and were not performed:

| Operation | Tool annotation | Boundary |
| --- | --- | --- |
| `open_binary` with `snapshot_path` | `readOnlyHint: false` | Creates a session and can start a provider. It is the only MCP route that loads the saved snapshot for function queries |
| `import_evidence_bundle` | `readOnlyHint: false` | Loads an exported bundle into the session |
| `inspect_analysis_view` | `readOnlyHint: false` | Reads retained session evidence. It does not import by itself |
| `analyze_function`, `read_bytes`, `procedure_pseudo_code`, `procedure_assembly` | `readOnlyHint: false` | Need an open target. They are unavailable in this namespace without provider configuration |
| `close_binary` with `snapshot_path` | `destructiveHint: true` | Writes a snapshot file |
| `export_evidence_bundle` | `destructiveHint: true` | Writes a file |

I did not start Ghidra, import the DLL, import the snapshot, open a target, or
run the vendor DLL. The offline snapshot parse and the byte checks read files
only.

Comms note: this session has no owned bus identity or sender tool. I did not
write to the peer bus or to the peer evidence directory. I read peer files
read-only. The peer packet and the peer review directory are unchanged.

## 7. Unresolved claims

Formal type claims:

1. The PE export table holds undecorated names. It holds no C++ mangling and no
   type metadata. The formal C++ declaration, parameter type, return type and
   constness are not established.
2. The Ghidra `longlong` and `ulonglong` types are decompiler artifacts. The
   snapshot marks them as such. They are not source types.
3. The body of the first function defines behavior only for `RCX` and `RAX`. It
   never reads `RDX`, `R8`, `R9` or stack arguments. The number of formal
   parameters is therefore not proven to be one.
4. The second function writes `EAX` on every path. Whether the source return
   type is 32-bit or a zero-extended 64-bit type is not established.
5. The signedness of the source-level comparisons is not established. The
   machine comparisons at `0x18000160d` (`JC`) and `0x18000161e` (`JA`) are
   unsigned. Equality against the all-ones sentinel is sign-neutral.

Unit and meaning claims:

6. The DLL bytes do not establish the unit of the count. The millisecond unit,
   the system-start epoch, and the sleep and hibernation behavior come from
   Microsoft documentation for `GetTickCount64`. That documentation describes
   the imported API. It does not describe this DLL.
7. A value of `0x337f9800` is 10 days only under the separately documented
   millisecond unit. The DLL bytes establish the constant and the clamp only.
8. The words "timeout", "deadline" and "remaining" are export names. They do not
   prove the caller semantics. The recovery proves only the shift, comparison
   and clamp arithmetic.

Wait-loop and runtime claims:

9. Neither body calls a wait, sleep, park, futex, `WaitOnAddress` or wake
   function. No wait-loop or thread-wakeup behavior is recovered.
10. The saved dossier has no CALL edge to either body. Caller behavior, thread
    context and the atomic-wait state machine remain unknown.
11. Reentrancy, thread safety and concurrent clock movement between two calls
    are not established.
12. No Windows execution, timing observation or runtime trace exists. The report
    is static only.

ABI claims:

13. `__fastcall` is a Ghidra observation. For x64 Windows it agrees with the
    standard Microsoft x64 register convention, but no source declaration
    confirms it.
14. Register saving at `0x1800015c0` and `0x1800015f0` (one `RBX` push and a
    32-byte stack allocation) is compiler output. It does not prove a source
    calling convention.
15. No Rust `extern` ABI mapping is claimed. A future native binding needs its
    own ABI verification.

Tool and evidence claims:

16. The snapshot profile binds Ghidra 12.1.4 with one parameter set. The offline
    parse does not re-verify the live provider. Current live profile
    compatibility is not established.
17. The saved evidence stays pinned to the tool version that produced it.

## 8. Limits

* This is a bounded static contract for two exports. The DLL has 32 named
  exports in 32 ordinal slots. This contract does not cover the other 30 exports
  or the rest of the library.
* It does not establish Windows parity, camera behavior, project compatibility
  or any DJI Studio application behavior.
* The clock unit, epoch and suspend property are external documentation facts.
  They are not recovered from the body bytes.
* No Linux clock selection is supported by evidence. The caller must supply the
  count.
* The 6654-vector oracle set derives from the packet reference model. It is an
  independent implementation check of the arithmetic. It is not a new
  decompilation.
* The peer packet and the peer review directory are historical and peer
  evidence. I did not modify them.

## 9. Tests for an independent Rust author

Required tests:

1. Sentinel, no clock read. Use a clock that panics or a call counter.
   `deadline(u64::MAX)` returns `u64::MAX` with 0 calls.
   `remaining_timeout(u64::MAX)` returns `0xffffffff` with 0 calls.
2. Exact call count. A counting clock must report exactly 1 call on every other
   path, for both functions.
3. Wrapping addition. `deadline(10, clock = u64::MAX - 10)` returns `u64::MAX`.
   `deadline(11, clock = u64::MAX - 10)` returns `0`. No panic in a debug build.
4. Sentinel collision. Assert that a finite input can return `u64::MAX`, so
   callers must not treat that value as reachable only from the sentinel input.
5. Return width. Assert the second function returns `u32`, and assert
   `u32::MAX` in the sentinel case.
6. Unsigned comparisons. `remaining_timeout(100, clock = 100)` returns 0.
   `remaining_timeout(99, clock = 100)` returns 0.
   `remaining_timeout(101, clock = 100)` returns 1.
7. Clamp boundaries. Let `cap = 0x337f9800`.
   Difference `cap - 1` returns `cap - 1`. Difference `cap` returns `cap`.
   Difference `cap + 1` returns `cap`. A huge finite difference returns `cap`.
8. High-bit inputs. Use inputs above `i64::MAX` with the high bit set. The
   results must follow the unsigned rules. A signed comparison fails these
   cases.
9. Differential oracle. Compare the implementation with
   `docs/evidence/atomic-wait-timeouts/reference_model.py` on at least 2000
   inputs. Include 0, 1, `cap - 1`, `cap`, `cap + 1`, `2^32 - 1`, `2^32`,
   `u64::MAX - 1` and `u64::MAX`.
10. No fallback clock. Inspect the module for `Instant`, `SystemTime`,
    `CLOCK_MONOTONIC`, `CLOCK_BOOTTIME` and uptime use. The only clock source
    must be the injected parameter.
11. No panic. Run the full vector set in a debug build. Confirm that the
    subtraction and the cast do not panic.

Local results of this scratch model, for reference:

* Rust 1.98.1, edition 2024, zero dependencies.
* `cargo test --offline` and `cargo test --offline --release`: 7 tests passed,
  0 failed, in both profiles.
* Oracle vectors: 6654 cases from the packet reference model, all pass.
* The packet `reference_model.py` rerun is byte-identical to
  `reference-model-results.txt`.

Suggested static gate for the future implementation: re-hash the two body
ranges of the pinned DLL and assert the pinned SHA-256 values before any native
comparison run.

## 10. Evidence files in this directory

| File | Content |
| --- | --- |
| `FINDINGS.md` | This report |
| `original-byte-check.json` | Own PE parse, body hashes, export table, IAT call targets, snapshot cross-checks |
| `export-inventory.json` | All 32 named exports with ordinals, RVAs and VAs |
| `snapshot-authentication.json` | Offline parse of the saved snapshot with the pinned REA 6.4.0 parser |
| `snapshot-dossier.json` | Sanitized procedure, reference, API and value-flow facts from the snapshot |
| `independent-disassembly.txt` | GNU and LLVM objdump text for both bodies |
| `rea-owned-provenance.json` | Owned namespace identity, commit, version, hashes |
| `rea-capability-summary.json` | Sanitized capability and provider availability result |
| `rea-owned-tools-catalog.json` | All 182 advertised tools with annotations and input keys |
| `rea-owned-session-raw.json` | Raw `binary_session` reply from the owned namespace |
| `rust-contract-model.rs` | Exact tested scratch model. Zero dependencies |
| `rust-model-test-output.txt` | Debug and release transcripts, vector identity, oracle diff |
| `vectors-generate.py` | Deterministic oracle vector generator. Seed `0xA70C1C`. Output SHA-256 `7e4b1e571d29825844808d75826d46e564a8a07fa33ee72e9ad80d6a37d5fab1`, 6654 vectors |
| `verify-offline.py` | Own PE parse, byte check and snapshot cross-check |
| `snapshot-dossier.py` | Sanitized snapshot dossier extractor |
| `authenticate-snapshot.mjs` | Offline snapshot parser check with pinned REA code |
| `rea-latest-probe.mjs` | Read-only `rea_latest` identity and tool catalog probe |
| `TASK-STATE.json` | Resume pins and open questions |
| `EVIDENCE-HASHES.json` | SHA-256 of every file in this directory except itself |

## 11. Resume notes

Pinned source: `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.
Snapshot: `9c03192eed52b16b3159ffbbde1cedb3749fe3e2814bbff038dd998e1189bea3`.
REA: commit `7ae3c50a9d49c480035855de9fcc4484befacd92`, package and server 6.4.0.
The next step is verifier feedback on this contract. A bounded pure Rust
implementation belongs in a separately reserved scope. Root message 3726 states
that root will reserve the pure Rust scope after contract approval.
