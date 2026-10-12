# MLT deque contract and reference cases

`contract-cases.json` records all 25 exact export names, addresses, ordinals, assembly evidence IDs, and one approved normal-return contract per export. It pins the independent review and source contract packet.

The fixture records a local original-byte recheck. It maps each saved inclusive VA range to file-backed PE bytes from the pinned DLL and compares body length and SHA-256 with the independent review's byte-check rows. The export wrapper checks cover 391 bytes. The sorted insertion helper at `0x180005b80` covers 339 bytes. This verifies source identity and saved body bytes. It does not prove runtime behavior.

`original-DEQUE-CASES.json` and `original-WINE-DEQUE-FINAL.jsonl` are exact copies of the root's sealed Wine reference cases and raw output. Their provenance, source build, hashes, groups, and limits are in `reference-provenance.json` and `original-reference-MANIFEST.json`. The Rust integration test compares all 481 records. It keeps `init.created` and `close.completed` as events, checks pointer and double values as full eight-byte bit patterns, does not read the int upper32 bits, and checks every comparator call in observed order.

The reference used Wine 11.17, native MSVC runtime dependencies, and Wine builtin UCRT/OS services. It does not establish Windows parity. The reference C caller and executable remain in the root evidence packet. This fixture copies only data and provenance. It does not port C or C++ code into the Rust application.
