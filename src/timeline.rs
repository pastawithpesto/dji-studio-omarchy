//! Constant-speed time mapping. Curved-speed interpolation is not recovered yet.
//! Positions and durations use microseconds. Valid positions are not clamped to a clip.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TimeError {
    InvalidSpeed,
    Overflow,
    InvalidFrameRate,
}

#[derive(Debug, Clone, Copy)]
pub struct ConstantSpeed {
    source_trim_start: i64,
    timeline_start: i64,
    speed: f64,
}

impl ConstantSpeed {
    /// The original caller's reverse/zero-speed policy is unresolved. This API
    /// deliberately accepts only finite positive rates until it is established.
    pub fn new(source_trim_start: i64, timeline_start: i64, speed: f64) -> Result<Self, TimeError> {
        if !speed.is_finite() || speed <= 0.0 {
            return Err(TimeError::InvalidSpeed);
        }
        Ok(Self {
            source_trim_start,
            timeline_start,
            speed,
        })
    }

    pub fn source_to_timeline(self, source: i64) -> Result<i64, TimeError> {
        let relative = source
            .checked_sub(self.source_trim_start)
            .ok_or(TimeError::Overflow)?;
        self.timeline_start
            .checked_add(round_time(relative as f64 / self.speed)?)
            .ok_or(TimeError::Overflow)
    }

    pub fn timeline_to_source(self, timeline: i64) -> Result<i64, TimeError> {
        let relative = timeline
            .checked_sub(self.timeline_start)
            .ok_or(TimeError::Overflow)?;
        self.source_trim_start
            .checked_add(round_time(relative as f64 * self.speed)?)
            .ok_or(TimeError::Overflow)
    }
}

fn round_time(value: f64) -> Result<i64, TimeError> {
    // Rust round() and the recovered llround both round ties away from zero.
    // i64::MAX as f64 is 2^63, so the upper boundary is exclusive.
    let rounded = value.round();
    if !rounded.is_finite() || rounded < i64::MIN as f64 || rounded >= 9_223_372_036_854_775_808.0 {
        return Err(TimeError::Overflow);
    }
    Ok(rounded as i64)
}

/// Recovered SpeedDurationAligned integer formula; preserves rational FPS
/// without converting to a floating-point frame rate. Uses wider intermediates
/// to reject overflow instead of wrapping. Negative-duration policy is unresolved.
pub fn align_duration_us(
    duration: i64,
    fps_numerator: i64,
    fps_denominator: i64,
) -> Result<i64, TimeError> {
    if fps_numerator <= 0 || fps_denominator <= 0 {
        return Err(TimeError::InvalidFrameRate);
    }
    let d = i128::from(duration);
    let p = i128::from(fps_numerator);
    let q = i128::from(fps_denominator);
    let numerator = (2 * d + 3)
        .checked_mul(p)
        .and_then(|v| v.checked_sub(1))
        .ok_or(TimeError::Overflow)?;
    let k = numerator / (2 * q * 1_000_000);
    let aligned = k
        .checked_mul(2 * q * 1_000_000)
        .and_then(|v| v.checked_add(p))
        .ok_or(TimeError::Overflow)?
        / (2 * p);
    i64::try_from(aligned).map_err(|_| TimeError::Overflow)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nonzero_trim_and_timeline_offsets_and_signed_ties() {
        let mapping = ConstantSpeed::new(100, 1_000, 2.0).unwrap();
        assert_eq!(mapping.source_to_timeline(103), Ok(1_002));
        assert_eq!(mapping.source_to_timeline(97), Ok(998));
        assert_eq!(mapping.timeline_to_source(1_002), Ok(104));
    }

    #[test]
    fn fractional_frame_boundary_is_preserved() {
        assert_eq!(align_duration_us(33_365, 30_000, 1_001), Ok(0));
        assert_eq!(align_duration_us(33_366, 30_000, 1_001), Ok(33_367));
        assert_eq!(align_duration_us(1_001_000, 30_000, 1_001), Ok(1_001_000));
    }

    #[test]
    fn invalid_values_and_overflow_are_reported() {
        assert_eq!(
            ConstantSpeed::new(0, 0, f64::NAN).unwrap_err(),
            TimeError::InvalidSpeed
        );
        assert_eq!(align_duration_us(1, 0, 1), Err(TimeError::InvalidFrameRate));
        assert_eq!(
            ConstantSpeed::new(i64::MIN, 0, 1.0)
                .unwrap()
                .source_to_timeline(i64::MAX),
            Err(TimeError::Overflow)
        );
        assert_eq!(
            ConstantSpeed::new(0, 0, 1.0)
                .unwrap()
                .source_to_timeline(i64::MAX),
            Err(TimeError::Overflow)
        );
    }
}
