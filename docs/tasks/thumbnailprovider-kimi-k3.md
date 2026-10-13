# ThumbnailProvider internal behavior

The user assigns Kimi K3 to continue reversing DJI DLLs. This task extends the
existing ThumbnailProvider export analysis to the remaining internal behavior.
Two Luna authors retain separate QuickLook correction scopes. A third Luna
reviews those corrected contracts independently.

Source: DJI Studio 1.0.0.30839 ThumbnailProvider.dll, 180408 bytes,
SHA-256 48d296e96d4e8626d477597afc6fb80c4752920eb5f529957ec36b085c0367a3.
Reuse the matching saved REA 6.4.0 / Ghidra 12.1.4 snapshot and evidence in
reconstruction/root-small-dll-benchmark-rea640-20261011/ThumbnailProvider.
Preserve the existing export report. It does not recover thumbnail decoding.

Trace the original CRecipeThumbProvider vtables, interface methods, stream
initialization, thumbnail entry, data producers, decoder dependencies, reference
counting and failure paths. Pin exact source bytes and saved evidence IDs.
Keep static facts, imported declarations and unresolved runtime behavior separate.
Write disjoint immutable analysis packets and request independent review.
Do not equate procedure accounting with recovered behavior.

This PR owns only this task plan. Research outputs use a new owned local folder.
Application source, imports, tool installation, vendor execution, native checks,
peer processes, merge and release are outside this grant.

Completion requires exact pinned internal contracts, a coverage ledger with
explicit gaps, and independent review. Implementation and Windows/reference
comparison remain separate. The requested model must be verified from an actual
worker receipt; configured credentials or a launch record alone do not prove it ran.
