# Original MLT sample timing and S16 volume in Rust

Own src/mlt/audio.rs, tests/mlt_audio.rs, tests/fixtures/mlt/audio/** and this plan.
The parent src/mlt.rs and format calculations stay with PR22. Other authors
retain their deque, property, interpolation and graph scopes. Do not edit lib.rs.

Preserve exact original names: mlt_sample_calculator,
mlt_sample_calculator_to_now and mlt_audio_update_volume.
Source DLL distribution1.0.0.30839 SHA-256
59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.
Actual REA6.4.0/Ghidra12.1.4 full dossiers and original-byte body checks exist.

The original sample timing uses ordered binary64 operations and truncating
SSE integer conversion. Its invalid conversion result is INT64_MIN under the
observed default masked floating environment. The frame sample difference
uses wrapping low32 arithmetic, including position+1 wrapping at INT64_MAX.

The original volume function supports only format1. Other formats return-1.
Gain1 returns0 without reading count or buffer. The positive/unordered gain
path includes NaN and uses a32-bit wrapping loop count. The saturation bounds
are -32767 and32767. NaN products become zero through the invalid conversion
low16 result. The nonpositive ordered path clears an independently calculated
signed-extended32-bit byte count. Preserve those distinct source paths.

Original native DLL/MSVC underWine11.17 produced1364 reference cases. They
include signed extrema, zero/NaN/infinity/subnormal frame rates, negative
frequency/position and gain, saturation, and untouched unsupported formats.
Wine UCRT/OS services remain. This is not native Windows parity.

Obtain independent exact-contract review before code. Adapt raw pointers to
borrowed mutable i16 slices with explicit pre-mutation bounds errors. Keep
original normal-return0/-1 statuses. Do not validate unused counts in the
unsupported-format or gain1 paths. Reject invalid raw memory access safely.
Do not claim arbitrary floating environments or exact Windows C ABI.

Implement supported Rust behavior, compare original fixture rows, test source
boundaries and explicit Rust buffer policy, run debug/release/fmt/Clippy, then
obtain independent exact-commit review and milestone. Preserve original names
and other authors' files. No entireDLL, graph/thread/plugin, UI/media/Windows
parity, merge or release claim.

## Implemented candidate

Independent exact contract approval:
f39f754a06d779d7381fd90014ee4ac4a1cb9c720113e1a19b8a9e38c676ed61.
Contract: e24341b731c2c75701460e00b59f07fa24710231e929c6fc3ec929144e7ff8af.
The three exact-name APIs are implemented in Rust. All1364 original cases match
in debug and release. Six tests pass in each profile, including safe atomic
bounds errors, unused-count bypass, distinct wrapping count paths and prefix
preservation. Formatting and test Clippy with warnings denied pass.

The source sample timing conversion uses INT64_MIN for masked invalid values.
The Rust code checks the source conversion interval before casting. Its volume
loop includes NaN gain, and the clear byte count remains independent of loop
count. Zero byte count can occur after wrapping even for INT32_MIN samples.
AudioBufferError and its byte-count fields are independent safe Rust policy.
No pointer, floating-exception flag, arbitrary rounding-mode or C ABI parity is
claimed. Exact source code review and milestone verification are still required.
