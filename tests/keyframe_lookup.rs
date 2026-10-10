// Exact transcription of sol-ui-review/resumed-20261010/lookup-fixtures.json,
// SHA-256 78655120b55e55d34027efa4749ee627c4a74b90ab6affce1ba396fca4f8a398.
// Expectations were analytically specified before implementation and independently
// reviewed by Astra140 and LunaB153/154. No expected index is calculated here.
// Pinned nle_core.dll 1.0.0.30839 SHA-256
// 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1,
// GetKeyframeAt 0x1800db580..0x1800db616, REA
// ev_68b48f0f4bbc508fc4dbe8b3edc30e2228421ca1e822af2c1bd0dcf940e1d06b.
// Four overflow cases and three constructor errors test independent native policy,
// not vendor wrap behavior. Raw timestamp units/axis and runtime parity are unknown.

use dji_reframe::timeline::{KeyframeIndexError, KeyframeTimeIndex};

macro_rules! lookup_case {
    ($name:ident, $times:expr, $query:expr, $expected:expr) => {
        #[test]
        fn $name() {
            let timestamps: &[i64] = &$times;
            let index = KeyframeTimeIndex::new(timestamps).unwrap();
            assert_eq!(index.lookup($query), $expected);
        }
    };
}

macro_rules! constructor_error_case {
    ($name:ident, $times:expr, $index:expr) => {
        #[test]
        fn $name() {
            assert_eq!(
                KeyframeTimeIndex::new(&$times).unwrap_err(),
                KeyframeIndexError::Unsorted { index: $index }
            );
        }
    };
}

// assembly_supported_nonoverflowing: No candidate exists.
lookup_case!(empty, [], 0, None);

// assembly_supported_nonoverflowing: Successor gap6.
lookup_case!(before_six, [100], 94, None);

// assembly_supported_nonoverflowing: Successor gap5 inclusive.
lookup_case!(before_five, [100], 95, Some(0));

// assembly_supported_nonoverflowing: Exact lower-bound at begin.
lookup_case!(exact_single, [100], 100, Some(0));

// assembly_supported_nonoverflowing: Predecessor gap5 inclusive.
lookup_case!(after_five, [100], 105, Some(0));

// assembly_supported_nonoverflowing: Predecessor gap6.
lookup_case!(after_six, [100], 106, None);

// assembly_supported_nonoverflowing: Predecessor gap5 wins over successor gap4.
lookup_case!(predecessor_not_nearest, [100, 109], 105, Some(0));

// assembly_supported_nonoverflowing: Predecessor gap4 wins over exact successor.
lookup_case!(exact_successor_masked, [100, 104], 104, Some(0));

// assembly_supported_nonoverflowing: Predecessor gap6 fails; successor gap4.
lookup_case!(successor_fallback, [100, 110], 106, Some(1));

// assembly_supported_nonoverflowing: Both gaps5; predecessor wins.
lookup_case!(two_equal_boundaries, [100, 110], 105, Some(0));

// assembly_supported_nonoverflowing: Predecessor gap6 and successor gap14.
lookup_case!(gap_left, [100, 120], 106, None);

// assembly_supported_nonoverflowing: Predecessor gap14 and successor gap6.
lookup_case!(gap_right, [100, 120], 114, None);

// assembly_supported_nonoverflowing: Lower-bound first equal, no predecessor.
lookup_case!(first_duplicate_exact, [100, 100, 110], 100, Some(0));

// assembly_supported_nonoverflowing: Predecessor is last duplicate.
lookup_case!(last_duplicate_predecessor, [100, 100, 110], 101, Some(1));

// assembly_supported_nonoverflowing: Last smaller record wins at gap4.
lookup_case!(
    duplicate_predecessor_masks_exact,
    [100, 100, 104],
    104,
    Some(1)
);

// assembly_supported_nonoverflowing: Both gaps5 in signed order.
lookup_case!(signed_previous, [-10, 0, 10], -5, Some(0));

// assembly_supported_nonoverflowing: Both gaps5 in signed order.
lookup_case!(signed_next, [-10, 0, 10], 5, Some(1));

// assembly_supported_nonoverflowing: Predecessor -1 wins over exact duplicates.
lookup_case!(signed_cross_zero, [-1, 0, 0], 0, Some(0));

// assembly_supported_nonoverflowing: Last predecessor gap1.
lookup_case!(signed_last, [-10, 0, 10], 11, Some(2));

// assembly_supported_nonoverflowing: First equal signed timestamp.
lookup_case!(negative_duplicate, [-10, -10], -10, Some(0));

// assembly_supported_nonoverflowing: No subtraction overflow.
lookup_case!(min_exact, [i64::MIN], i64::MIN, Some(0));

// assembly_supported_nonoverflowing: Gap5 within i64.
lookup_case!(
    min_successor_boundary,
    [-9223372036854775803],
    i64::MIN,
    Some(0)
);

// assembly_supported_nonoverflowing: Gap5 within i64.
lookup_case!(
    min_predecessor_boundary,
    [i64::MIN],
    -9223372036854775803,
    Some(0)
);

// assembly_supported_nonoverflowing: No subtraction overflow.
lookup_case!(max_exact, [i64::MAX], i64::MAX, Some(0));

// assembly_supported_nonoverflowing: Gap5 within i64.
lookup_case!(
    max_successor_boundary,
    [i64::MAX],
    9223372036854775802,
    Some(0)
);

// assembly_supported_nonoverflowing: Gap5 within i64.
lookup_case!(
    max_predecessor_boundary,
    [9223372036854775802],
    i64::MAX,
    Some(0)
);

// proposed_independent_overflow_policy: Wider gap rejects distant predecessor before accepting exact successor; vendor wrapped gap selects index0.
lookup_case!(full_span_exact, [i64::MIN, i64::MAX], i64::MAX, Some(1));

// proposed_independent_overflow_policy: Wider gap rejects distant successor; vendor wrapped gap accepts index0.
lookup_case!(full_span_before, [i64::MAX], i64::MIN, None);

// proposed_independent_overflow_policy: Wider gap rejects distant predecessor; vendor wrapped gap accepts index0.
lookup_case!(full_span_after, [i64::MIN], i64::MAX, None);

// proposed_independent_overflow_policy: Mathematical gap2^63; vendor wrapped negative gap passes.
lookup_case!(min_to_zero, [i64::MIN], 0, None);

// proposed_independent_input_validation: first descending adjacent pair.
constructor_error_case!(constructor_first_descent_1, [2, 1], 1);

// proposed_independent_input_validation: first descending adjacent pair.
constructor_error_case!(constructor_first_descent_2, [1, 3, 2, 0], 2);

// proposed_independent_input_validation: first descending adjacent pair.
constructor_error_case!(
    constructor_first_descent_3,
    [i64::MIN, i64::MAX, i64::MIN],
    2
);
