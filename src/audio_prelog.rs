//! Signed host-value i16 conversion and the RMS stage preceding the deferred log.
//!
//! Source: audio_highlight.dll 1.0.0.30839, SHA256
//! `14c3f88484c3a0fe673fcf19494f3394aad102a7e220ba464520e127eda166e3`,
//! FUN_180013780. The approved CONTRACT-V2 and fixture pins are recorded in
//! `tests/fixtures/audio_prelog/README.md`.
//!
//! Recovered static facts: exact 2^-15 normalization, separate f32 square,
//! sequential f64 sum/division/sqrt, f32 RMS rounding, then widening for the
//! binary64 threshold comparison. Bit conformance uses the independent round
//! to nearest, ties to even (RNE) model; the original Windows rounding
//! environment is unknown. No log or dB result is computed here.
//!
//! Independent interface design: safe borrowed host values (byte decoding is a
//! separate boundary), caller-owned output, deterministic capacity preflight,
//! distinct outcomes, and no allocation. Sound references and the exclusive
//! output borrow supply the safe aliasing contract. Invalid native pointer
//! behavior, caller-result usage, sample rate, and channels are not established.

/// The outcome after normalization and the pre-log RMS comparison.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Level {
    /// Nonempty input whose widened f32 RMS is at least the binary64 threshold.
    /// These are RMS bits, not a dB value or a substituted logarithm result.
    DeferredLog { rms_f32_bits: u32 },
    /// Nonempty input below the threshold; the output prefix has been written.
    Silence,
    /// Empty input; the entire output remains untouched.
    Empty,
}

/// Successful conversion of exactly `written` output entries.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Conversion {
    pub written: usize,
    pub level: Level,
}

/// An independent safe-interface capacity error, detected before any write.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConvertError {
    OutputTooSmall { needed: usize, provided: usize },
}

/// Normalize host-value samples into the caller's buffer and return pre-log RMS.
///
/// On success only `out[..input.len()]` is written. Excess output entries retain
/// their raw bits, including NaN payloads and signed zeros. Empty input and all
/// errors leave the entire output unchanged. No count cap, allocation, unsafe
/// code, FFI, or logarithm is used.
///
/// The source's negative-mean sqrt fallback is unreachable for these valid i16
/// values under the RNE model: all squares and their finite sum are nonnegative.
///
/// # Errors
/// Returns [`ConvertError::OutputTooSmall`] when the output is shorter than the
/// input, before normalization or any output write.
pub fn convert_i16_rms(input: &[i16], out: &mut [f32]) -> Result<Conversion, ConvertError> {
    if out.len() < input.len() {
        return Err(ConvertError::OutputTooSmall {
            needed: input.len(),
            provided: out.len(),
        });
    }
    if input.is_empty() {
        return Ok(Conversion {
            written: 0,
            level: Level::Empty,
        });
    }

    let mut sum: f64 = 0.0;
    for (&sample, output) in input.iter().zip(out.iter_mut()) {
        let normalized = f32::from(sample) * f32::from_bits(0x3800_0000);
        *output = normalized;
        // Keep this f32 operation separate from the widening and addition.
        let square: f32 = normalized * normalized;
        sum += f64::from(square);
    }
    let mean: f64 = sum / input.len() as f64;
    let rms: f32 = mean.sqrt() as f32;
    let level = if f64::from(rms) < f64::from_bits(0x3ddb_7cdf_d9d7_bdbb) {
        Level::Silence
    } else {
        Level::DeferredLog {
            rms_f32_bits: rms.to_bits(),
        }
    };
    Ok(Conversion {
        written: input.len(),
        level,
    })
}
