# Signal self type qualification

This additive Rust generator change fixes a C++ lookup error in CXX-Qt0.10.0.
A class can hide a namespace with the same identifier inside generated signal
helpers. The original native class `FpsDetect::FpsDetect` has this form.

`src/generator/cpp/signal.rs` adds an absolute `::` prefix when the first
namespace identifier equals the class identifier. The same helper supplies the
connect declaration, definition, callback type, and signal member pointer.
Other generated type spelling stays unchanged. The option for unscoped member
enums is separate and stays unchanged.

The regression test covers mutable and const receivers, a nested namespace,
and two names without the lookup collision. The original failed Qt build is
preserved outside source. Its log SHA-256 is
`f2d97ad8d41cbbe60132da716cf74a7d8c2c2c78b160ea904f3b1b5f2e05a26f`.
Native Qt compilation remains required. No generated C++ is edited.

The original source archive, file hashes, and licenses remain pinned in
UPSTREAM.json. This is the third changed upstream implementation file. The
two added integration test entries are local Cargo manifest changes.
