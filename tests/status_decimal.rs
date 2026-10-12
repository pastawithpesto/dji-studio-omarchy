#[path = "../src/status_decimal.rs"]
mod status_decimal;

use status_decimal::{DecimalWriteError, MAX_I32_DECIMAL_BYTES, append_i32_decimal};

const CASES: &[(i32, &[u8])] = &[
    (0, b"0"),
    (1, b"1"),
    (-1, b"-1"),
    (10, b"10"),
    (-10, b"-10"),
    (1009, b"1009"),
    (-1009, b"-1009"),
    (i32::MAX, b"2147483647"),
    (i32::MIN, b"-2147483648"),
];

#[test]
fn exact_original_contract_oracles_preserve_prefix_and_suffix() {
    assert_eq!(MAX_I32_DECIMAL_BYTES, 11);
    for &(value, expected) in CASES {
        let mut buffer = [0xa5; 32];
        buffer[..3].copy_from_slice(&[0, 255, b':']);
        let end = append_i32_decimal(&mut buffer, 3, value).unwrap();
        assert_eq!(end, 3 + expected.len());
        assert_eq!(&buffer[..3], &[0, 255, b':']);
        assert_eq!(&buffer[3..end], expected);
        assert!(buffer[end..].iter().all(|&b| b == 0xa5));
    }
}

#[test]
fn every_capacity_boundary_is_exact_and_errors_are_atomic() {
    for &(value, expected) in CASES {
        for available in 0..=expected.len() {
            let mut storage = [0x7f; 16];
            let original = storage;
            let output = &mut storage[..2 + available];
            let result = append_i32_decimal(output, 2, value);
            if available < expected.len() {
                assert_eq!(
                    result,
                    Err(DecimalWriteError::InsufficientCapacity {
                        required: expected.len(),
                        available,
                    })
                );
                assert_eq!(storage, original);
            } else {
                assert_eq!(result, Ok(2 + expected.len()));
                assert_eq!(&storage[2..2 + expected.len()], expected);
                assert_eq!(&storage[..2], &original[..2]);
                assert_eq!(
                    &storage[2 + expected.len()..],
                    &original[2 + expected.len()..]
                );
            }
        }
    }
}

#[test]
fn invalid_used_length_has_precedence_and_leaves_bytes_unchanged() {
    for used in [3, usize::MAX] {
        let mut output = [42; 2];
        assert_eq!(
            append_i32_decimal(&mut output, used, i32::MIN),
            Err(DecimalWriteError::InvalidLength { used, capacity: 2 })
        );
        assert_eq!(output, [42; 2]);
    }
    assert_eq!(
        append_i32_decimal(&mut [], 0, 0),
        Err(DecimalWriteError::InsufficientCapacity {
            required: 1,
            available: 0
        })
    );
}

#[test]
fn repeated_appends_preserve_the_existing_output() {
    let mut output = [b'?'; 32];
    output[..7].copy_from_slice(b"status=");
    let end = append_i32_decimal(&mut output, 7, -10).unwrap();
    let end = append_i32_decimal(&mut output, end, 1009).unwrap();
    assert_eq!(&output[..end], b"status=-101009");
    assert!(output[end..].iter().all(|&byte| byte == b'?'));
}

#[test]
fn deterministic_full_width_values_match_independent_standard_decimal_format() {
    // Standard Display is an independent test oracle for canonical decimal.
    // This comparison does not execute or validate the vendor allocator.
    let mut bits = 0_u32;
    for _ in 0..4096 {
        bits = bits.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
        let value = bits as i32;
        let expected = value.to_string();
        let mut output = [0xa5; MAX_I32_DECIMAL_BYTES];
        let end = append_i32_decimal(&mut output, 0, value).unwrap();
        assert_eq!(&output[..end], expected.as_bytes());
    }
}
