# Original MLT audio and image format calculations in Rust

Own src/mlt.rs, src/mlt/audio_format.rs, src/mlt/image_format.rs,
tests/mlt_formats.rs, tests/fixtures/mlt/formats/** and this plan.
The whole-DLL task plan remains in PR20. Other authors own property/container,
service/timeline and interpolation/profile/animation/geometry child files.
The existing integrator retains src/lib.rs. Do not modify it here.

Preserve these original function names:
mlt_audio_format_name, mlt_audio_format_size, mlt_audio_format_samples,
mlt_image_format_name, mlt_image_format_id and mlt_image_format_size.
Use actual REA6.4.0/Ghidra12.1.4 dossiers and complete original body byte checks.
Original MLT build1.0.0.30839 SHA-256:
59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.

The original image size calculation adds one to height in 32-bit arithmetic.
It does not simply multiply visible width and height. Audio sample division
uses unsigned 64-bit division for formats1..5 and signed 32-bit division for
format6. Preserve those operations and source boundaries. Recover return-width
and argument contracts before choosing the Rust signatures.

Original DLL format outputs are available in the independently generated
reference-packet under reconstruction/root-mlt-complete-rea640-20261011.
Wine11.17 observations include negative integers and large dimensions.
The1900 scalar cases replay identically with both Wine built-in MSVC libraries
and the original native MSVC dependencies. The Wine UCRT/OS boundary remains.
These observations are not a Windows comparison.

Obtain independent exact-contract review before code. Implement the supported
calculations in Rust. Test actual reference outputs and independently supported
integer operations, divisor errors, optional output fields and exact strings.
Run debug/release, formatting and Clippy checks. Obtain independent exact-commit
review and milestone verification. Register only available supported children
in src/mlt.rs. Test through standalone compilation until the existing integration
owner reserves library registration. Do not create success stubs for missing APIs.

This is a bounded subsystem of the requested whole DLL. No entire-DLL,
callback/threading, Windows/camera/GPU/UI/project parity, merge or release claim.

## Implemented candidate

The six exact-name functions are implemented in audio_format.rs and
image_format.rs. The parent registers these available children only. Its
explicit child paths support both standalone tests and later library registration.

Exact calculation contract: 4690c7e09b66742bf3d0a7f36b5b8fe84f063a22567a7e2d79a04a9872cc5704.
Independent contract approval: 83cdc7329a0ba4f2d439b7e3c008bcb3fed0e23ef91f84a79f7e7a9c6b1be104.
Original reference fixtures: 1612 format cases and 29 additional lookup/null-output
cases. All1641 cases match in both debug and release. Six tests pass in each
profile. Formatting, test Clippy with warnings denied and standalone module
metadata compilation pass. The initial path-based test import failed to find
child modules; the explicit parent paths fix that issue.

The original C return prototype of mlt_audio_format_samples remains unresolved.
Its Rust Result<u64, AudioFormatArithmeticError> preserves measured RAX bits.
DivisionByZero and SignedDivisionOverflow are independent safe Rust error names.
The source DIV/IDIV paths trap for those inputs. The Rust interface does not
claim a recovered C ABI. Signed integer parameters, immutable Rust strings,
borrowed byte slices and optional mutable references are explicit native
adaptations. Lookup stops at NUL and requires no UTF-8 conversion.

The fixture provenance file pins both original reference packets, exact input
hashes, contract/review hashes and Wine limits. Source code and these tests need
independent exact-commit review. Library registration, full DLL coverage and
the remaining subsystems are separate work. No source stubs are present.
