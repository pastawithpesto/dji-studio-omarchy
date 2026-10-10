# Recovered DJI metadata descriptors

`dji-metadata-descriptors.pb` is an unchanged copy of the 16-file descriptor set recovered under `sol-review/descriptors/` in the reconstruction workspace. SHA-256: `45bdd29930f3d10f46ed51a7ee3b8917e3806a4bc425f136c034908c4fc578bb` (60819 bytes).

Source: DJI Studio Windows build 1.0.0.30839 `VinceEditor.dll`, SHA-256 `9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42`. `sol-review/descriptors/manifest.json` and `sol-review/resumed-metadata-20261010/source-pins.json` record the original embedded blob offsets and confirm byte equality. The two decoded root types are `oqb101.ProductMeta` (`dvtm_oqb101.proto`) and `wab530.ProductMeta` (`dvtm_eagle4_wab530.proto`); both depend on the unqualified common `dvtm_library.proto` types. The other descriptors are retained as original evidence; their presence does not enable other camera schemas in the decoder.

The whole-buffer parsing contract is `sol-review/METADATA-PARSER-CONTRACT.md` and the bounded native design is `sol-review/resumed-metadata-20261010/CONTRACT.md`, approved by Astra on bus message 56. Static packet forwarding at `0x18034cb36–0x18034cb42` and parser wrappers ending at `0x1804a2720` support parsing a complete selected metadata packet. No vendor code is executed by this decoder.

These schemas establish field types, not camera timestamp units, coordinate conventions, encryption/compression processing or successful decoding of a real recording. No Windows/camera parity claim follows from these artifacts or synthetic fixtures.
