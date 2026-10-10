//! Literal expectations from pre-implementation export-range-fixtures.json
//! SHA256 77823c3379e8b534243e2190fc953a9ec35c10d44608aa628254f32745f10b57.
//! Independently checked by LunaA5/406 and primary Astra436. Values have opaque
//! units; these cases do not assert producer reachability or export output parity.

use dji_reframe::timeline::{ExportRangeError, ExportRangePlan, plan_export_range};

#[test]
fn ordinary_offset() {
    assert_eq!(
        plan_export_range(100, 160),
        Ok(ExportRangePlan::WriteRange {
            start: 100,
            duration: 60,
        })
    );
}

#[test]
fn zero_start() {
    assert_eq!(
        plan_export_range(0, 1),
        Ok(ExportRangePlan::WriteRange {
            start: 0,
            duration: 1,
        })
    );
}

#[test]
fn equal_zero() {
    assert_eq!(
        plan_export_range(0, 0),
        Ok(ExportRangePlan::NoExplicitRangeWrite)
    );
}

#[test]
fn reversed_positive() {
    assert_eq!(
        plan_export_range(20, 10),
        Ok(ExportRangePlan::NoExplicitRangeWrite)
    );
}

#[test]
fn negative_start() {
    assert_eq!(
        plan_export_range(-7, -2),
        Ok(ExportRangePlan::WriteRange {
            start: -7,
            duration: 5,
        })
    );
}

#[test]
fn cross_zero() {
    assert_eq!(
        plan_export_range(-3, 4),
        Ok(ExportRangePlan::WriteRange {
            start: -3,
            duration: 7,
        })
    );
}

#[test]
fn max_duration() {
    assert_eq!(
        plan_export_range(i64::MIN, -1),
        Ok(ExportRangePlan::WriteRange {
            start: i64::MIN,
            duration: i64::MAX,
        })
    );
}

#[test]
fn max_adjacent() {
    assert_eq!(
        plan_export_range(i64::MAX - 1, i64::MAX),
        Ok(ExportRangePlan::WriteRange {
            start: i64::MAX - 1,
            duration: 1,
        })
    );
}

#[test]
fn min_adjacent() {
    assert_eq!(
        plan_export_range(i64::MIN, i64::MIN + 1),
        Ok(ExportRangePlan::WriteRange {
            start: i64::MIN,
            duration: 1,
        })
    );
}

#[test]
fn first_duration_overflow() {
    assert_eq!(
        plan_export_range(i64::MIN, 0),
        Err(ExportRangeError::DurationOverflow)
    );
    // Frozen vendor SUB divergence: the positive mathematical 2^63 wraps to MIN.
    assert_eq!(0_i64.wrapping_sub(i64::MIN), i64::MIN);
}

#[test]
fn full_span_overflow() {
    assert_eq!(
        plan_export_range(i64::MIN, i64::MAX),
        Err(ExportRangeError::DurationOverflow)
    );
    // Frozen vendor SUB divergence: the positive mathematical 2^64-1 wraps to -1.
    assert_eq!(i64::MAX.wrapping_sub(i64::MIN), -1);
}

#[test]
fn equal_max() {
    assert_eq!(
        plan_export_range(i64::MAX, i64::MAX),
        Ok(ExportRangePlan::NoExplicitRangeWrite)
    );
}
