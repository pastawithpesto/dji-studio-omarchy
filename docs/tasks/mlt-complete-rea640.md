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
