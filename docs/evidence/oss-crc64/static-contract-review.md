# Independent OSS CRC64 static contract review

Disposition: **approved_static_contract** for author/CONTRACT.md SHA-256 `5e0bf31515b7630513a05ba6ca9c28328863de6106d7c9fed51746ffb21958f5`. This supports the root author implementation grant for PR30's declared paths. It does not approve Rust code or original-DLL fixtures.

Independent original PE parsing resolved both named exports and all jump links to the actual bodies at RVA 0x1b4bc0 and 0x1b4850. All 104 author manifest files, 47 raw calls, six four-facet function packets, and 16 provider byte witnesses matched their pins. The witnesses match 1139 original bytes, including complete 293-byte Compute and 294-byte Combine bodies. Compute's three pdata fragments form one body; no fragment was mistaken for full coverage.

Original instructions support polynomial 0xC96C5795D7870F42, initial/final complement, one-byte prefix/tail loads, little-endian qword slicing and table7..0 order. Empty input reads no buffer bytes and returns the incoming CRC, including the native null/zero path. Combine tests and shifts the complete unsigned 64-bit count. Zero length returns crc1 without applying crc2. Its 64-column helpers and repeated squaring handle bit63 and u64::MAX. No signed truncation or Combine complement is supported by the bytes.

An independent bitwise oracle agrees with the instruction-level slicing model in 816 cases covering all eight alignment residues and arbitrary seeds. Forward polynomial multiplication and exponentiation agree with all 64 one-bit operator basis vectors and 90 full-width Combine cases. One hundred seeded concatenation and incremental cases also pass. These are offline arithmetic checks, not execution of the original DLL.

The initializer pointer, jump stub, init and generator are byte-backed. All eight 256-entry u64 tables occupy 16384 zero-filled virtual .data bytes; no baked file table was assumed. The enclosing startup array and loader execution remain unresolved static facts. Inferred qword pointer types, undefined public signatures, the security-cookie injection warning and unrelated analysis diagnostics stay qualified.

The safe Rust slice, byte recurrence instead of slicing optimization, immutable compile-time table and stack matrix choices are explicitly independent adaptations. Keep the exact original function names. Corrected, independently sealed original-DLL observations and an exact Rust commit review remain required. The unsealed fixture failures are not accepted as an oracle. No full SDK, C++ ABI, malformed-pointer, UI, media or Windows/application parity claim is approved.

This reviewer executed only owned offline Python models and LLVM disassembly. No author driver, Ghidra session or vendor DLL was executed. Root relays comms. Previous benchmark review files and peer source remain untouched.
