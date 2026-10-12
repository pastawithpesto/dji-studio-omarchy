# MLT deque contract cases

`contract-cases.json` records all 25 exact export names, addresses, ordinals, assembly evidence IDs, and one approved normal-return contract per export. It pins the independent review and the source contract packet.

The fixture also records a local original-byte recheck. It maps each saved inclusive VA range to file-backed PE bytes from the pinned DLL and compares body length and SHA-256 with the independent review's byte-check rows. The export wrapper checks cover 391 bytes. The sorted insertion helper at `0x180005b80` covers 339 bytes. This verifies source identity and saved body bytes. It does not prove runtime behavior.

The static cases back `tests/mlt_deque.rs`. They are not original-DLL runtime captures. Root is preparing Wine operation-sequence fixtures. Add those as separate files after receipt and hash verification. Keep both static and runtime provenance explicit.
