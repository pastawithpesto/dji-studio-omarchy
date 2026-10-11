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
