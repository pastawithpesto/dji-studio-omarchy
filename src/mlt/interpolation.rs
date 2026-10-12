//! Pure Rust `f64` adapters for five independently approved MLT scalar contracts.
//!
//! These signatures are Rust adaptations. They do not claim the original
//! library's C or C++ prototypes. Nonfinite behavior and floating-point
//! exception guarantees are outside these contracts.

/// Adapts `mlt_circular_ease_in` for finite inputs with a nonnegative radicand.
///
/// The approved numeric domain is `1.0 - time * time >= 0.0`. Behavior outside
/// this domain is not part of the numeric contract.
pub fn mlt_circular_ease_in(time: f64) -> f64 {
    let square = time * time;
    let radicand = 1.0 - square;
    1.0 - radicand.sqrt()
}

/// Internal binary search used by `mlt_cublic_linear_ease_in_out`.
///
/// `FUN_18001a320` is an analysis label for the original internal function,
/// not an original exported API. The loop has no added iteration cap.
fn cubic_linear_parameter(time: f64) -> f64 {
    let mut low = 0.0_f64;
    let mut high = 1.0_f64;

    loop {
        let middle = (high + low) * 0.5;
        let one_minus_middle = 1.0 - middle;

        let first_term = ((one_minus_middle * 0.30000000000000004) * one_minus_middle) * middle;
        let second_term = ((one_minus_middle * 2.7) * middle) * middle;
        let third_term = (middle * middle) * middle;
        let curve = (first_term + second_term) + third_term;

        if curve <= time {
            low = middle;
        } else {
            high = middle;
        }

        let width = high - low;
        if width < 0.0001 {
            return (high + low) * 0.5;
        }
    }
}

/// Adapts the original export `mlt_cublic_linear_ease_in_out`.
///
/// The original spelling contains `cublic`. The helper and leaf use separate
/// binary64 operations in original instruction order. This pure Rust signature
/// is not a recovered C or C++ prototype.
pub fn mlt_cublic_linear_ease_in_out(time: f64) -> f64 {
    let parameter = cubic_linear_parameter(time);
    let twice = parameter + parameter;
    let factor = 3.0 - twice;
    let scaled = factor * parameter;
    scaled * parameter
}

/// Adapts the observed binary64 result of `mlt_discrete_interpolation`.
///
/// The original body zeroes XMM0. This Rust unary `f64` interface is an
/// independent observation adapter, not the original decompiler's `void`
/// prototype.
pub fn mlt_discrete_interpolation(_time: f64) -> f64 {
    0.0
}

/// Adapts the observed binary64 identity result of `mlt_linear_interpolation`.
///
/// The original `RET 0` preserves XMM0 in the reviewed call context. This Rust
/// `f64` interface is an independent adapter, not a recovered C++ alias type.
pub fn mlt_linear_interpolation(time: f64) -> f64 {
    time
}

/// Adapts `mlt_smooth_interpolation` while keeping its binary64 operations
/// separate and in the original instruction schedule.
pub fn mlt_smooth_interpolation(time: f64) -> f64 {
    let square = time * time;
    let twice = time + time;
    let factor = 3.0 - twice;
    factor * square
}
