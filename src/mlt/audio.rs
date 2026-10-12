//! Original MLT sample timing and S16 volume calculations.
//!
//! DJI Studio distribution 1.0.0.30839, mltframework-win.dll SHA-256
//! 59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c.
//! Supports the observed default nearest-even, masked SSE environment's output
//! values. Floating exception flags and the Windows C ABI are not reproduced.

/// Independent safe Rust error for a source raw-memory access beyond the slice.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AudioBufferError {
    pub required_bytes: u64,
    pub available_bytes: u64,
}

/// Original export at 0x18001e340. Preserves arithmetic order and conversion.
pub fn mlt_sample_calculator_to_now(fps: f64, frequency: i32, position: i64) -> i64 {
    if fps == 0.0 {
        return 0;
    }
    let adjustment = if position < 0 { -0.5 } else { 0.5 };
    let product = f64::from(frequency) * position as f64;
    let quotient = product / fps;
    let value = quotient + adjustment;
    // CVTTSD2SI64 returns the signed minimum for masked invalid conversion.
    // Rust's default float cast instead saturates, so check the source range.
    if (-9_223_372_036_854_775_808.0..9_223_372_036_854_775_808.0).contains(&value) {
        value as i64
    } else {
        i64::MIN
    }
}

/// Original export at 0x18001e2f0. Returns the wrapped low 32-bit difference.
pub fn mlt_sample_calculator(fps: f64, frequency: i32, position: i64) -> i32 {
    let next = mlt_sample_calculator_to_now(fps, frequency, position.wrapping_add(1));
    let current = mlt_sample_calculator_to_now(fps, frequency, position);
    (next as i32).wrapping_sub(current as i32)
}

/// Original export at 0x18001cb80, with a bounded borrowed-buffer adaptation.
///
/// Unsupported formats return Ok(-1) without reading the buffer or counts.
/// Gain 1 returns Ok(0) with the same bypass. Other successful paths return
/// Ok(0). An insufficient slice returns an independent error before mutation.
/// Parameter names and AudioBufferError are independent Rust identifiers.
pub fn mlt_audio_update_volume(
    format: i32,
    buffer: &mut [i16],
    gain: f64,
    samples: i32,
    channels: i32,
) -> Result<i32, AudioBufferError> {
    if format != 1 {
        return Ok(-1);
    }
    if gain == 1.0 {
        return Ok(0);
    }
    let product = samples.wrapping_mul(channels);
    // COMISD(0, gain); JC also selects this path for unordered (NaN) gain.
    let scale = gain > 0.0 || gain.is_nan();
    let required_bytes = if scale {
        u64::from(product as u32) * 2
    } else {
        // The clear path doubles in 32 bits, then signed-extends to size_t.
        i64::from(product.wrapping_mul(2)) as u64
    };
    // A valid Rust i16 slice's byte extent is bounded by isize::MAX.
    let available_bytes = buffer.len() as u64 * 2;
    if required_bytes > available_bytes {
        return Err(AudioBufferError {
            required_bytes,
            available_bytes,
        });
    }
    // The wide check proves this fits usize and the provided slice.
    let prefix = &mut buffer[..(required_bytes / 2) as usize];
    if scale {
        for sample in prefix {
            let value = f64::from(*sample) * gain;
            *sample = if value.is_nan() {
                // Source MINSD preserves the NaN; invalid CVTTSD2SI32 yields
                // INT32_MIN, whose low 16 bits are zero.
                0
            } else if value < -32767.0 {
                -32767
            } else if value > 32767.0 {
                32767
            } else {
                value as i16
            };
        }
    } else {
        prefix.fill(0);
    }
    Ok(0)
}
