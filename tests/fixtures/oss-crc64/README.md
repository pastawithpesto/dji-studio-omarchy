# Alibaba Cloud OSS CRC64 original-export reference

This folder contains bounded calls to two named exports in the original DJI
Studio 1.0.0.30839 SDK DLL. The DLL SHA-256 is
`083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1`.

`observed.tsv` and `join-observed.tsv` are raw stdout from the x64 Windows PE
harness under Wine 11.17. The first file contains 3,153 ComputeCRC64 and 576
CombineCRC64 calls. The second contains 24 CombineCRC64 calls built from
observed ComputeCRC64 prefix and suffix results. The complete structured record
is `ORIGINAL-EXPORT-FIXTURE.json`. It gives each case inputs, deterministic
input-data SHA-256 values, and the exact 64-bit result returned by the DLL.

`PE-EXPORT-AND-CHAIN.json` records exports and rel32 jump chains parsed from
the original PE bytes. The harness resolves the exact decorated names using
`GetProcAddress`. Its Windows x64 function-pointer signatures are
`u64 (u64, const void *, u64)` and `u64 (u64, u64, u64)`. It used bounded
buffers for ComputeCRC64 and scalar arguments for CombineCRC64. It did not call
SDK request, network, upload, or timing methods.

`SYNTHETIC-ORACLE-CHECK.json` is a separate analyst cross-check. It reports
whether an independently written bitwise CRC recurrence and logarithmic GF(2)
operator agree with the observed output. This file is not DLL output.
`SEAL-RECEIPT.json` records exact hashes, tool binaries, versions, dependencies,
commands, line counts, and retained failed probes.

The raw failed probes remain available. The first probe used the wrong buffer
offset when populating alignment cases. The second probe described suffix bytes
from pattern index zero. Neither probe is used as the final fixture. Their raw
stdout files and reasons are listed in the receipt.

The first `wineboot -u` attempt stalled with an RpcSs startup error after
creating the isolated prefix. Direct runs then succeeded under that same prefix.
The Wine result is not a native Windows or DJI application parity claim.

To reproduce from this folder, build `original_exports.exe` with the command
arrays in the fixture, generate the initial inputs with
`python3 build_fixture.py prepare`, and run the PE in the recorded
`wineprefix`. Then run `python3 build_fixture.py extend-joins`, copy
`join-cases.tsv` to `cases.tsv`, and run the PE again. Both commands and all
tool hashes are recorded in the receipt. `initial-cases.tsv` preserves the
exact first-pass input order. `SHA256SUMS.txt` pins the handoff files.
