# Complete mltframework-win.dll reconstruction

The first property-data packet covers ten functions. The user now requests the
whole DLL. Inventory and account for every original export and analyzed function,
then implement supported behavior in Rust. Preserve exact original API names,
including original spelling. Do not fill unknown behavior with a stub or a new UI.

Original distribution: DJI Studio 1.0.0.30839.
Original mltframework-win.dll: 711864 bytes, SHA-256
59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.
Use installed REA 6.4.0 with Ghidra 12.1.4. Reuse the exact matching property
snapshot and immutable reports before new queries. Serialize provider imports
through the existing lock. Preserve all failure records and original files.

The PE has 2646 named exports. 784 names start with mlt_. Those names occupy
737 unique addresses. An export alias is not a separate recovered function.
Do not assume that decorated C++ exports, CRT helpers or callback-dependent
paths are complete because the C entry points were decompiled.

Plan:

1. Save full provider function, EAT, IAT and string inventories.
2. Map aliases, thunks, internal callees and original byte ranges.
3. Maintain per-address states for evidence, contract review, Rust code,
   code review, reference tests and unresolved external dependencies.
4. Recover each original subsystem using its original names. Include property
   values, events, profiles, images, audio, interpolation, animation, geometry,
   containers, service graphs, producers, consumers, filters, transitions,
   playlists, multitracks, tractors, factories and repositories. Account for the
   additional original mlt_drama, mlt_parallel and mlt_series interfaces.
5. Reserve each disjoint implementation scope in its own draft PR. Obtain
   supported contracts and independent review before implementing them.
6. Test original DLL operations in an isolated owned runtime when feasible.
   Preserve outputs as reference fixtures. Wine results must be labeled Wine
   observations. They do not establish execution on Windows.
7. Integrate exact reviewed source without altering other authors' files.
8. Publish exact remaining gaps. Mark completion only after the required
   implementation, independent review and reproducible reference gates pass.

This PR owns only this task plan. Source authors reserve separate files.
The full local evidence lives in reconstruction/root-mlt-complete-rea640-20261011.
Prior property evidence lives in reconstruction/root-mlt-properties-rea640-20261011.
The prior report requires its additive clarification. The fifth argument stored
at property+0x40 has no recovered semantic name. Same-pointer replacement
suppresses the old data callback, but does not guarantee pointer survival.

No complete-DLL, application, Windows, camera, GPU, UI or project compatibility
claim is established by this reservation. No merge or release is requested.

## Progress at 2026-10-12 01:23 UTC

The full native sweep captured 1879 canonical provider function bodies. All
1944 distinct body ranges, totaling 221379 bytes, match the original PE.
The 2646 named exports occupy 1563 addresses. Shared addresses retain their
original aliases. Capturing a shared body does not establish each alias type.
The 31 nonexecutable export addresses remain data and type obligations.

The complete REA evidence bundle exported successfully. The later close and
snapshot request timed out. Preserve CLOSE-FAILURE.json and use the captured
packets and exported bundle. No successful new full snapshot is claimed.

PR22 contains six Rust format adapters. Exact candidate ea05ec0c has independent
code approval and milestone verification. It passes 1641 original-DLL reference
cases. PR23 contains 25 deque adapters. Exact additive candidate a940a214 corrects
the signed low32 count predicate and awaits independent re-review. Its 20 tests
include all 481 original reference records and 64 arithmetic boundary pairs.
PR24 contains three audio adapters at adad20a1. It passes 1364 original timing
and S16 volume cases. Exact independent code review is in progress.

These 34 Rust adapters remain on their separate branches. Main application
module registration, native Windows comparisons and whole-DLL completion remain
pending. Original-DLL runtime observations use Wine11.17 and the original native
MSVC dependencies, with Wine UCRT and OS services.

The next author tasks cover five independently approved direct interpolation
adapters and additive corrections to the service and timeline contracts.
The complete dispatcher, thirty other direct easing functions, property/cache/
pool/tokeniser, profile/animation/geometry, graph/runtime/external dependencies
and decorated C++ obligations remain unfinished.

The additive local per-export and per-function progress record is
reconstruction/root-mlt-complete-rea640-20261011/progress-20261012T0123/COVERAGE.json,
SHA-256 e9186f81b5c368983eee053e20fb65da3551128da7fca077886ba87d744fbcca.
Its input/output manifest is
7ddd81c6508fd078424cf90717d8eb22fe0075438ffccdd2a2d5b0d9e64c99ff.
This record reports bounded task progress. It does not approve new contracts.
