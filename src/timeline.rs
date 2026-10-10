//! Constant-speed time mapping. Curved-speed interpolation is not recovered yet.
//! Time-mapping positions and durations use microseconds and are not clamped to a clip.
//! The keyframe index uses opaque timestamps whose units and axis are caller supplied.

/// Independent input-validation policy for the borrowed keyframe index.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KeyframeIndexError {
    /// The latter element of the first descending adjacent pair.
    Unsorted { index: usize },
}

/// Experimental lookup over borrowed, nondecreasing signed timestamps.
///
/// The slice and query must already share the same opaque axis. This API does
/// not convert camera timestamps, packet PTS/DTS, or source/timeline positions.
/// It returns indices into the original slice and never sorts or deduplicates.
///
/// Source: nle_core.dll build 1.0.0.30839, SHA-256
/// 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1,
/// GetKeyframeAt 0x1800db580..0x1800db616; sol-review/nle-keyframe-decompile.json,
/// REA ev_68b48f0f4bbc508fc4dbe8b3edc30e2228421ca1e822af2c1bd0dcf940e1d06b.
/// Original assembly: sol-ui-review/resumed-20261010/keyframe-original-assembly.txt.
/// Approved bounded contract: sol-ui-review/resumed-20261010/REPORT.md, Astra140.
///
/// Borrowing, sorted-input validation and i128 distance arithmetic are independent
/// native policies. Widened distances deliberately differ from the vendor's
/// wrapping subtraction at extreme spans. Timestamp units, producer duplicate
/// legality, UI reachability, payload/interpolation and Windows parity are unknown.
#[derive(Debug)]
pub struct KeyframeTimeIndex<'a> {
    timestamps: &'a [i64],
}

impl<'a> KeyframeTimeIndex<'a> {
    /// Validate nondecreasing order in O(n) without allocating or changing the slice.
    /// Empty slices and equal timestamps are accepted under the native policy.
    pub fn new(timestamps: &'a [i64]) -> Result<Self, KeyframeIndexError> {
        if let Some(index) = timestamps.windows(2).position(|pair| pair[0] > pair[1]) {
            return Err(KeyframeIndexError::Unsorted { index: index + 1 });
        }
        Ok(Self { timestamps })
    }

    /// Return an original-slice index within five raw timestamp units in O(log n).
    ///
    /// The predecessor of the first timestamp >= query wins when within five;
    /// otherwise that lower-bound record wins when within five. A qualifying
    /// predecessor can therefore beat a closer or exact later record. Both
    /// boundaries are inclusive. None means neither candidate qualifies.
    pub fn lookup(&self, query: i64) -> Option<usize> {
        let lower_bound = self.timestamps.partition_point(|&time| time < query);
        if let Some(previous) = lower_bound.checked_sub(1)
            && i128::from(query) - i128::from(self.timestamps[previous]) <= 5
        {
            return Some(previous);
        }
        if let Some(&next) = self.timestamps.get(lower_bound)
            && i128::from(next) - i128::from(query) <= 5
        {
            return Some(lower_bound);
        }
        None
    }
}

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

/// Recovered SpeedDurationAligned integer formula for ordinary positive FPS
/// and nonoverflowing vendor arithmetic. Source: nle_core.dll build 1.0.0.30839,
/// SHA-256 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1,
/// 0x1800f82c0; astra-review/nle-duration-alignment-assembly.json,
/// REA ev_6dbb2d987fe9a7fff6f6e6aeef72db3ac5b69e4b2ac1fc0b58e7f5fe1e1f60d5.
///
/// Independent API policies: invalid FPS returns Err(InvalidFrameRate), whereas
/// the recovered JLE paths return zero at 0x1800f831a. The i64 FPS inputs widen
/// the recovered signed 32-bit domain; wider intermediates reject overflow
/// instead of wrapping. Negative-duration policy and Windows parity are unresolved.
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

/// Independent native representation of an optional explicit range write.
/// Values share one caller-selected opaque domain; this is not an FFI pair.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportRangePlan {
    /// Omit the explicit write. No whole-project, reset or success meaning follows.
    NoExplicitRangeWrite,
    /// Preserve the supplied start and a positive, representable duration.
    WriteRange { start: i64, duration: i64 },
}

/// Independent checked-duration policy, distinct from vendor wrapping subtraction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportRangeError {
    /// The mathematical positive difference exceeds i64::MAX.
    DurationOverflow,
}

/// Plan a range write without allocation, side effects or timestamp conversion.
///
/// Return [`ExportRangePlan::NoExplicitRangeWrite`] when `end <= start`.
/// Otherwise preserve `start` and compute mathematical `end - start` in i128,
/// rejecting a positive duration above i64::MAX. Negative and zero values are
/// admitted by the independent native value contract; producer legality is unknown.
/// The caller decides applicability: no timeline/context lifecycle is modelled.
///
/// Source: nle_core.dll 1.0.0.30839, SHA256
/// 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1,
/// function 0x18011ee00, signed branch/pair at 0x18011f559..0x18011f580,
/// REA ev_1ec411b0cece4b20897bc7c0147cb20b261afdf17abf00e9620176ef42af2d0c.
/// Approved EXPORT-RANGE-CONTRACT.md SHA256
/// 0dd13adc37ca0ee43acf088aa61990fbdd1d1c4b9b3610f8e31dabe3b854daa0, Astra436.
///
/// The checked error deliberately differs from the vendor's 64-bit SUB:
/// MIN-to-zero wraps to MIN; MIN-to-MAX wraps to -1. Units, defaults, concrete
/// virtual-call behavior, renderer/output and Windows parity are not established.
pub fn plan_export_range(start: i64, end: i64) -> Result<ExportRangePlan, ExportRangeError> {
    if end <= start {
        return Ok(ExportRangePlan::NoExplicitRangeWrite);
    }
    let duration = i64::try_from(i128::from(end) - i128::from(start))
        .map_err(|_| ExportRangeError::DurationOverflow)?;
    Ok(ExportRangePlan::WriteRange { start, duration })
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
