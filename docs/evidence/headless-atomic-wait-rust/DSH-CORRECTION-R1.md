# Correction R1, additive record

This record corrects three evidence statements in `FINDINGS.md`. It is additive.
`FINDINGS.md` stays sealed and unchanged with SHA-256
`ecb83d11d0fea9a406a2b99055f81c8ef6785cfba6f062937bf4ccd2466c293a`. The first
turn outputs stay unchanged. This turn performed one read-only identity query,
one offline PE parse and no analysis target work.

## Recall of the approved cap, sentinel and clock-call facts

These facts do not change:

* `__std_atomic_wait_get_deadline`: the input is 64 bits in `RCX`. The input
  `0xffffffffffffffff` returns `0xffffffffffffffff` and reads no clock. Every
  other input reads `KERNEL32.dll!GetTickCount64` exactly once and adds the two
  64-bit values with `ADD RAX, RBX` modulo 2^64. There is no carry check and no
  saturation.
* `__std_atomic_wait_get_remaining_timeout`: the input is 64 bits in `RCX`. The
  input `0xffffffffffffffff` returns `RAX = 0x00000000ffffffff` and reads no
  clock. Every other input reads the clock exactly once. An unsigned compare
  returns 0 when the clock value is equal to or above the input. Otherwise the
  body subtracts the clock value from the input and clamps with an unsigned `JA`
  against the cap `0x337f9800` (864000000). A difference above the cap returns
  the cap. Equality returns the cap.
* The cap is a body constant. The millisecond unit and the 10-day value come
  from the separate Microsoft `GetTickCount64` documentation. The DLL bytes
  establish neither.

## Correction 1: the two export structures were reversed

Old text in `FINDINGS.md` section 2 and section 5:

* "The export address table holds both RVAs at `0x18000531d` and `0x180005322`."
* "`.rdata` at `0x180006660` and `0x180006664` holds a table of 4-byte RVAs."
* "This is an observation of a registration table."
* "Incoming references are DATA only, from the export table, the `.rdata`
  registration table and `.pdata`."

Corrected facts from my own offline PE parse:

| Item | Value |
| --- | --- |
| Export directory header | RVA `0x6610`, file offset `0x5410`, data directory size 1348 |
| `AddressOfFunctions` (the EAT) | RVA `0x6638`, file offset `0x5438` |
| `AddressOfNames` | RVA `0x66b8` |
| `AddressOfNameOrdinals` | RVA `0x6738` |
| Ordinal base | 1 |
| EAT index 10, ordinal 11 | slot RVA `0x6660`, slot VA `0x180006660`, bytes `c0150000`, value RVA `0x15c0` |
| EAT index 11, ordinal 12 | slot RVA `0x6664`, slot VA `0x180006664`, bytes `f0150000`, value RVA `0x15f0` |

* VA `0x180006660` and VA `0x180006664` are the aligned EAT slots for ordinals
  11 and 12.
* VA `0x18000531d` and VA `0x180005322` are unaligned 4-byte RVA fields inside
  packed records with an observed 5-byte stride. The observed bytes are
  `c015000002` and `f015000002`. The next records hold RVAs `0x1630`, `0x1760`,
  `0x1790` and `0x17a0`. These references are not EAT slots.
* Withdrawn claims: the registration table interpretation of VA
  `0x180006660` and VA `0x180006664`, and any registration or caller role for VA
  `0x18000531d` and VA `0x180005322`. No role was established for those packed
  records.
* Corrected incoming DATA reference map for each body: the EAT slot, the packed
  record RVA field and the `.pdata` RUNTIME_FUNCTION begin address. No CALL edge
  reaches either body in the saved dossier.

## Correction 2: the return type test was too strong

Old text in `FINDINGS.md` section 9, test 5:

* "Return width. Assert the second function returns `u32`, and assert
  `u32::MAX` in the sentinel case."

Corrected facts:

* The formal C++ return declaration stays unknown. A Rust `u32` return is not a
  recovered source type.
* The machine fact does not change. Every remaining-timeout path writes `EAX`
  and zero-extends into `RAX`. The observed sentinel result is
  `0x00000000ffffffff`. Every observed finite result is at most `0x337f9800`.
* The approved independent Rust API supplies the clock as `FnMut() -> u64` and
  returns the observed `RAX` bits as `u64` for both functions. That form is
  faithful to the zero-extension.
* The trait and `u32` model in `FINDINGS.md` section 4 and in
  `rust-contract-model.rs` is an optional independent design. It is not the
  required original API.

Corrected test requirement: assert the sentinel case returns the `u64` value
`0x0000_0000_FFFF_FFFF`. Assert that no finite path returns a value above
`0x337f9800`. Assert that no path sets a bit above bit 31. Do not require a
`u32` return type.

## Correction 3: the bodies are not contiguous

Old text in `FINDINGS.md` section 2:

* "The two bodies are contiguous and non-overlapping."

Corrected facts:

* The bodies do not overlap. They are not contiguous.
* First body exclusive range `0x15c0..0x15e1`, 33 bytes.
* Second body exclusive range `0x15f0..0x1628`, 56 bytes.
* Gap `0x15e1..0x15f0`, 15 bytes. The gap bytes are 15 times `0xcc`
  (`cccccccccccccccccccccccccccccc`).
* The `.pdata` RUNTIME_FUNCTION entries confirm the same two exclusive ranges.

## Resumed turn tool provenance

* The owned namespace `rea_latest` now uses
  `/home/violence/Work/dji-headless-rea-e4d3e139-20261012` at upstream commit
  `e4d3e1399d9cd4932653e7015a1bf8589e56029d`, package and running server 6.4.0.
* One read-only `binary_session` identity query passed. Server `rea` 6.4.0,
  alignment `aligned`, `open: false`, 184 advertised tools. The first turn
  observed 182 tools on the earlier tool revision.
* The first-turn tool stays recorded as commit
  `7ae3c50a9d49c480035855de9fcc4484befacd92`, package 6.4.0. This record does
  not replace it.
* Sol restored the saved snapshot with the latest `e4d` tool, replayed the two
  cached dossiers, read both complete bodies from a fresh Ghidra 12.1.4 provider
  at 768M, and verified equality with the original bytes. Those checks are Sol's
  independent checks. This record makes no fresh decompilation or provider-query
  claim.

## Remaining limits

* No formal C++ declaration, parameter type, return type or signedness.
* No caller, wait-loop, thread-wakeup or reentrancy claim.
* No role for the packed `.rdata` records at RVA `0x531d` and RVA `0x5322`.
* The clock unit, epoch and suspend behavior stay external Microsoft API
  documentation facts.
* No new analysis target, import, Ghidra start or vendor execution in this turn.
