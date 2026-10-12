//! Original `mlt_audio_format_*` calculations.
//!
//! Source: mltframework-win.dll, DJI Studio distribution 1.0.0.30839,
//! SHA-256 59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.
//! The original names and strings remain exact. Rust parameter names and the
//! error type below are independent implementation identifiers.

/// Safe Rust errors for the original hardware division traps.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AudioFormatArithmeticError {
    DivisionByZero,
    SignedDivisionOverflow,
}

/// Original export at 0x18001ca30. The borrowed C strings adapt to Rust strings.
pub fn mlt_audio_format_name(format: i32) -> &'static str {
    match format {
        0 => "none",
        1 => "s16",
        2 => "s32",
        3 => "float",
        4 => "s32le",
        5 => "f32le",
        6 => "u8",
        _ => "invalid",
    }
}

/// Original export at 0x18001cb20, preserving the low 32-bit arithmetic.
pub fn mlt_audio_format_size(format: i32, samples: i32, channels: i32) -> i32 {
    let scale = match format {
        1 => 2,
        2..=5 => 4,
        6 => 1,
        _ => return 0,
    };
    samples.wrapping_mul(channels).wrapping_mul(scale)
}

/// Original export at 0x18001cab0, preserving the observed RAX result bits.
///
/// Formats 1..5 use unsigned 64-bit division after signed extension. Format 6
/// uses signed 32-bit division and zero-extends its quotient bits. The source
/// C return prototype is unresolved. This Rust u64 result is an explicit
/// register-result adaptation. Typed errors replace original division traps.
pub fn mlt_audio_format_samples(
    format: i32,
    bytes: i32,
    channels: i32,
) -> Result<u64, AudioFormatArithmeticError> {
    let scale = match format {
        1 => 2_i64,
        2..=5 => 4,
        6 => {
            if channels == 0 {
                return Err(AudioFormatArithmeticError::DivisionByZero);
            }
            return bytes
                .checked_div(channels)
                .map(|quotient| u64::from(quotient as u32))
                .ok_or(AudioFormatArithmeticError::SignedDivisionOverflow);
        }
        _ => return Ok(0),
    };
    if channels == 0 {
        return Err(AudioFormatArithmeticError::DivisionByZero);
    }
    let dividend = i64::from(bytes) as u64;
    let divisor = i64::from(channels).wrapping_mul(scale) as u64;
    Ok(dividend / divisor)
}
