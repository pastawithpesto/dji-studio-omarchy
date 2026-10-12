# Original OSS CRC64 arithmetic

The Rust module implements `AlibabaCloud::OSS::ComputeCRC64` and
`AlibabaCloud::OSS::CombineCRC64` with their original names. It follows their
actual arithmetic bodies and helpers in DJI Studio build `1.0.0.30839`, DLL
SHA-256 `083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1`.

The export jump chains reach `ComputeCRC64` at RVA `0x1b4bc0..0x1b4ce4` and
`CombineCRC64` at RVA `0x1b4850..0x1b4975`. The table generator, initialization
wrapper and GF(2) helpers are also captured. Fresh owned REA upstream
`edf46248f2a44b4e5776518489fee09d0fc4516b`, package/server `6.4.0` and Ghidra
`12.1.4` produced six complete function records and 16 exact original-byte
comparisons covering 1,139 bytes. The earlier benchmark's 100 jump stubs are
not an implementation oracle.

[The exact static contract](contract.md) is preserved unchanged. Its SHA-256
is `5e0bf31515b7630513a05ba6ca9c28328863de6106d7c9fed51746ffb21958f5`.
[Independent static review](static-contract-review.json), SHA-256
`24c6336adf1698ecf12d26132c5449c20b72098cf0d03c97f0e6060c0fe54d0c`, approves
that bounded contract. It does not approve implementation or reference fixtures.
[Provenance](provenance.json), [original bytes](original-byte-capture.json)
and the selected raw `rea/` facets preserve addresses, source/tool identities,
evidence IDs and limitations. The original full local packet manifest is
[author-packet-manifest.json](author-packet-manifest.json). The selected subset
has its own [manifest](selected-evidence-manifest.json). Original DLLs, complete
Ghidra projects and the full local archive remain outside this repository.

The safe API replaces the original pointer/count pair with a byte slice.
`ComputeCRC64` uses an immutable base table and the equivalent byte recurrence
instead of alignment-sensitive slicing. It complements the seed and returned
internal state and preserves every seed bit for an empty slice. `CombineCRC64`
uses fixed stack matrices and unsigned 64-bit logical shifts. It returns crc1
unchanged for zero len2, including when crc2 is nonzero. Compile-time table
initialization and bounded slices are independent Rust lifecycle and safety
choices. Foreign C++ ABI and malformed-pointer behavior are not claimed.

The exact independently authored [original-DLL fixture](../../../tests/fixtures/oss-crc64/ORIGINAL-EXPORT-FIXTURE.json)
has SHA-256 `f9215b491f62b2a4cefc945c6f8f30b155b12d90c76699c3a12ddbe4fb862624`.
It records 3,153 Compute and 600 Combine results observed under Wine 11.17.
The replay checks every returned word and 24 valid joins. It includes all byte
values, arbitrary seed bits, alignment and bulk/tail boundaries, bounded inputs
up to 1,048,576 bytes, and full-width u64 combine lengths without allocating
such buffers. Independent payload reconstruction verifies every one of the
3,153 recorded input SHA-256 values. The source, raw input/output TSVs and seal
receipt accompany the fixture. Separate synthetic checks are clearly labeled.
Failed harness offset and suffix probes remain pinned in the original receipt.
The Rust author did not execute a duplicate Wine harness.

An additive [runtime trace receipt](runtime-trace-receipt.json), SHA-256
`c945b0b1e5fc9a493e7f2a10ebb384ae72a4353c3007438455f884ff8c450209`, preserves
the original seal and records a separate replay with `WINEDEBUG=+loaddll`.
The [module manifest](runtime-loader-manifest.json), SHA-256
`b3d03808aba2cc5ad5b5a8f09802791dc23281b5fbb16de3f580213f3dad6cc7`, identifies
26 loaded modules and pins their implementations. The actual SDK DLL,
libcurl and libeay32 loaded as native PE modules. MSVC and UCRT support loaded
as Wine builtins. The traced 3,729 primary rows agree with the sealed primary
observations by case ID and all fields. The 24 join rows were observed separately.
This establishes that runtime configuration under Wine, not native MSVC or
Windows parity. The initial receipt's lack of a loader trace remains historical;
the additive trace does not replace or alter the original fixture.

Eight additional tests use an independent bitwise Compute oracle and a
matrix-free reflected polynomial-product Combine oracle. They cover every byte
with every individual seed bit, every unsigned length bit, zero-length rules,
incremental/concatenation identities and zero-byte advance composition.
The focused test target directly includes the module because another PR owns
`src/lib.rs` registration.

Current checks are recorded in [validation.json](validation.json). The two APIs
and fixture comparison remain a bounded candidate until exact implementation
and reference review finish. Full SDK behavior, network methods, C++ ABI,
invalid pointers, loader failure behavior, native Windows execution, UI,
processing, camera and project parity remain outside this claim.
