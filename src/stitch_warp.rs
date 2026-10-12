//! Scalar coordinates from the original DJI warp-img-v2.frag equations.
//!
//! Reference: DJI Studio 1.0.0.30839, stitch_with_sym.dll SHA-256
//! 82c9e7f0c51b5a2d7c13597022326bdaee2dfd92824bd67790336029d55a67a8.
//! Shader VA 0x1802600a0, raw offset 0x25f4a0; host 0x180104440.
//! Approved K-WARP contract SHA-256:
//! 844661a879fc91c77907685a7821588f61039206b181a01d13b8c84bdec1414f.
//! Independent contract review SHA-256:
//! 2c4d8f548916a01d809f5617ce04cbf94c20dca245b742faf2465b2fd7151bb6.
//!
//! Domain checks and typed errors are independent Rust policy. Callers supply
//! flow samples. This module does not sample images or establish GPU parity.

/// Largest approved dimension, with exact integer conversion to f32.
pub const MAX_DIMENSION: u32 = 16_777_216;

/// Supplied values for the original shader coordinate equations.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WarpInput {
    pub uv: [f32; 2],
    pub flow_sample: [f32; 2],
    pub flow_scale: f32,
    /// Dimensions of the left input image used by textureSize in the shader.
    pub input_size: [u32; 2],
    /// Dimensions of the output texture used by the host step uniforms.
    pub output_size: [u32; 2],
}

/// Coordinates after the shader's single x correction, with inclusive y checks.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WarpCoordinates {
    pub left: [f32; 2],
    pub right: [f32; 2],
    pub left_y_valid: bool,
    pub right_y_valid: bool,
}

/// Independent checked errors, not original DJI status codes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KernelError {
    InvalidDimensions,
    NonFiniteInput,
    InvalidDomain,
    NonFiniteResult,
}

/// Calculate the two warp coordinates without texture sampling or allocation.
///
/// Dimensions must be in 1..=MAX_DIMENSION. UV components must be in [0, 1].
/// All scalar inputs and final coordinates must be finite. Error precedence is
/// dimensions, nonfinite inputs, UV domain, then nonfinite results. This order
/// is independent Rust policy. Input and output dimensions can differ.
///
/// Each x greater than 1 loses 1 once. Each x below 0 then gains 1 once.
/// Extreme results can remain outside [0, 1]. Y coordinates are preserved;
/// the caller decides how to handle an invalid y or sample an image.
pub fn warp_coordinates(input: WarpInput) -> Result<WarpCoordinates, KernelError> {
    if input
        .input_size
        .iter()
        .chain(input.output_size.iter())
        .any(|&size| !(1..=MAX_DIMENSION).contains(&size))
    {
        return Err(KernelError::InvalidDimensions);
    }
    if input
        .uv
        .iter()
        .chain(input.flow_sample.iter())
        .any(|value| !value.is_finite())
        || !input.flow_scale.is_finite()
    {
        return Err(KernelError::NonFiniteInput);
    }
    if input.uv.iter().any(|value| !(0.0..=1.0).contains(value)) {
        return Err(KernelError::InvalidDomain);
    }

    let blend_right = input.uv[1];
    let blend_left = 1.0 - blend_right;
    let mut left = [0.0; 2];
    let mut right = [0.0; 2];
    for axis in 0..2 {
        let flow = input.flow_sample[axis] * input.flow_scale;
        let step = 1.0 / input.output_size[axis] as f32;
        let position = input.uv[axis] * input.input_size[axis] as f32;
        left[axis] = (position - flow * blend_right) * step;
        right[axis] = (position + flow * blend_left) * step;
    }
    left[0] = correct_x_once(left[0]);
    right[0] = correct_x_once(right[0]);

    if left
        .iter()
        .chain(right.iter())
        .any(|value| !value.is_finite())
    {
        return Err(KernelError::NonFiniteResult);
    }
    Ok(WarpCoordinates {
        left,
        right,
        left_y_valid: (0.0..=1.0).contains(&left[1]),
        right_y_valid: (0.0..=1.0).contains(&right[1]),
    })
}

fn correct_x_once(mut x: f32) -> f32 {
    if x > 1.0 {
        x -= 1.0;
    }
    if x < 0.0 {
        x += 1.0;
    }
    x
}
