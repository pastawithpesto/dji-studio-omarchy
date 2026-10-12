//! Original `mlt_image_format_*` calculations.
//!
//! Source: mltframework-win.dll, DJI Studio distribution 1.0.0.30839,
//! SHA-256 59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.
//! Rust borrowed slices and optional references adapt the original pointers.

/// Original export at 0x18001e160. Returns exact original format names.
pub fn mlt_image_format_name(format: i32) -> &'static str {
    match format {
        0 => "none",
        1 => "rgb24",
        2 => "rgb24a",
        3 => "yuv422",
        4 => "yuv420p",
        5 => "opengl",
        6 => "glsl",
        7 => "glsl_texture",
        _ => "invalid",
    }
}

/// Original export at 0x18001e0f0. Matches IDs 0..7, then returns 8 on failure.
///
/// Bytes after the first NUL are ignored. A slice without NUL ends at its Rust
/// length. No UTF-8 conversion, case folding or normalization occurs.
pub fn mlt_image_format_id(name: Option<&[u8]>) -> i32 {
    let Some(name) = name else {
        return 8;
    };
    let end = name
        .iter()
        .position(|byte| *byte == 0)
        .unwrap_or(name.len());
    let name = &name[..end];
    (0..8)
        .find(|format| name == mlt_image_format_name(*format).as_bytes())
        .unwrap_or(8)
}

/// Original export at 0x18001e1f0, including its height increment and size cap.
///
/// Height increments modulo 2^32 before signed extension. Products preserve
/// the source's 64-bit register bits. The original unsigned size cap rejects
/// values above INT_MAX. The optional bpp output is assigned before rejection.
/// Formats 6 and 7 return 4, including for unusual dimensions.
pub fn mlt_image_format_size(format: i32, width: i32, height: i32, bpp: Option<&mut i32>) -> i32 {
    let width = i64::from(width) as u64;
    let height = i64::from(height.wrapping_add(1)) as u64;
    let area = width.wrapping_mul(height);
    let (bytes_per_pixel, size) = match format {
        1 => (3, area.wrapping_mul(3)),
        2 | 5 => (4, area.wrapping_mul(4)),
        3 => (2, area.wrapping_mul(2)),
        4 => (1, area.wrapping_mul(3) >> 1),
        6 | 7 => (0, 4),
        _ => (0, 0),
    };
    if let Some(output) = bpp {
        *output = bytes_per_pixel;
    }
    if size <= i32::MAX as u64 {
        size as i32
    } else {
        0
    }
}
