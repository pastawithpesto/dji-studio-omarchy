# Latest REA saved evidence verification

The reviewer verified the saved contract with the latest owned engine.
The fresh upstream check immediately before this run identified official REA
main and owned HEAD as `e4d3e1399d9cd4932653e7015a1bf8589e56029d`.
The owned path is `/home/violence/Work/dji-headless-rea-e4d3e139-20261012`.
The package and `Client.getServerVersion()` both report 6.4.0.
`latest-restore-provenance.json` records the entry and dist hashes.

The reviewer held the shared `ghidra-import.lock` with nonblocking `flock`.
Grant 3729 permitted one owned startup for this exact DLL. No peer installation
or session changed. No vendor code executed.

The snapshot open succeeded. The live selected profile digest is
`1974e8b97d53c06a1572c109c6497629fdd8513abc4625ca30722f223f0b47bb`.
The selected provider is Ghidra 12.1.4. The complete original source hash matches
`ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.
The two `analyze_function` calls reused the saved dossiers. Their normalized
results, pseudocode, assembly, and procedure records match the saved records
exactly. The new replay evidence IDs are:

- `ev_283ae45a360b3f84643b1a9bee12b19c04bc7775f171e26f181b213960f4b597`
- `ev_dda368976eaf3dbaefc8b4fadd82a9a94b7fb1445f3ec8f93406404fe2d3723a`

The two uncached `read_bytes` calls used the newly started provider. They read
all 33 and 56 original body bytes. Both complete results match the original
source bytes exactly. Their evidence IDs equal the older content IDs because
the provider results and source identity match:

- `ev_48a7b709ac9087965e997936bb23d572d78a5b9d85300eae635fb3105e01a9a0`
- `ev_53de07bd265eccc7c5842600bb699a4f8dde5b9e4027d21b71b2f7a7927aa679`

The actual session observations refine the earlier source-only startup
prediction. The composed saved-snapshot route completed `open_binary` with
process lineage `not_observed`. The first uncached byte query started the new
Ghidra image import and default analysis. The later session record verifies
launcher PID 140239, parent PID 139677, process group 140239, and a decompiler
descendant. The reviewer read the JVM heap argument as `-Xmx768M` during startup.
The recorded run ID is `7ee81e3a-a59e-4b88-b7bf-b5a112fea43e`.

The evidence bundle was exported before close. It contains ten records and
187,020 bytes. The owned session closed successfully. A later nonblocking lock
probe succeeded. The original complete source hash still matched after queries.

This run verifies a fresh provider image and the saved contract bytes. It is
one new import with automatic analysis, two saved dossier replays, and two new
complete provider byte reads. It is not two new function decompilations. The
old evidence retains its original tool provenance. Native execution, formal
C++ types, Windows ABI, wait-loop behavior, wakeups, and application parity
remain outside the review.
