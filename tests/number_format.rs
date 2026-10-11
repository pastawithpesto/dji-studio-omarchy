//! Frozen703 policy/literals plus independently computed exact-rational samples.
//! Original source/runtime and Windows equivalence are separate review gates.
use dji_reframe::number_format::{HARD_MAX_OUTPUT_BYTES, NumberError, format_finite_bits};
use serde_json::Value;

fn bits(s: &Value) -> u64 {
    u64::from_str_radix(s.as_str().unwrap(), 16).unwrap()
}
fn frozen(s: &str) -> Value {
    serde_json::from_str(s).unwrap()
}
fn assert_output(input: u64, expected: &[u8]) {
    for poison in [0x00, 0xa5, 0xff] {
        let mut buffer = [poison; 96];
        let before = input;
        let destination = &mut buffer[3..93];
        let returned = format_finite_bits(&input, destination, 64).unwrap();
        assert_eq!(returned, expected, "bits {input:016x}");
        assert_eq!(returned.as_ptr(), destination.as_ptr());
        assert_eq!(input, before);
        assert_eq!(&buffer[..3], &[poison; 3]);
        assert!(buffer[3 + expected.len()..].iter().all(|&x| x == poison));
    }
}
#[test]
fn frozen_literals_signed_zero_ties_and_notation() {
    let corpus = frozen(include_str!("fixtures/number_format/literal-fixtures.json"));
    assert_eq!(corpus["fixtures"].as_array().unwrap().len(), 52);
    for row in corpus["fixtures"].as_array().unwrap() {
        assert_output(
            bits(&row["bits"]),
            row["expected"].as_str().unwrap().as_bytes(),
        );
    }
}
#[test]
fn independent_rational_exponents_guards_midpoints_and_subnormals() {
    let corpus = frozen(include_str!(
        "fixtures/number_format/rational-fixtures.json"
    ));
    assert!(corpus["cases"].as_array().unwrap().len() > 26000);
    for row in corpus["cases"].as_array().unwrap() {
        let input = bits(&row["bits"]);
        let positive = row["expected"].as_str().unwrap();
        assert_output(input, positive.as_bytes());
        let negative = format!("-{positive}"); // Test oracle text only.
        assert_output(input | 1 << 63, negative.as_bytes());
    }
}
#[test]
fn frozen_policy_error_precedence_unchanged_and_prefix_ownership() {
    let corpus = frozen(include_str!(
        "fixtures/number_format/native-policy-fixtures.json"
    ));
    assert_eq!(corpus["cases"].as_array().unwrap().len(), 42);
    for row in corpus["cases"].as_array().unwrap() {
        let input = bits(&row["bits"]);
        let cap = row["max_output_bytes"].as_u64().unwrap() as usize;
        let len = row["destination_bytes"].as_u64().unwrap() as usize;
        let mut output = vec![0xa5; len + 6];
        let expected = &row["expected"];
        match format_finite_bits(&input, &mut output[3..3 + len], cap) {
            Ok(prefix) => {
                assert_eq!(prefix, expected["bytes"].as_str().unwrap().as_bytes());
                let used = prefix.len();
                assert!(output[3 + used..].iter().all(|&x| x == 0xa5));
            }
            Err(error) => {
                let number = |key: &str| expected[key].as_u64().unwrap() as usize;
                let wanted = match expected["error"].as_str().unwrap() {
                    "InvalidLimit" => NumberError::InvalidLimit {
                        provided: number("provided"),
                        maximum: number("maximum"),
                    },
                    "NonFinite" => NumberError::NonFinite { bits: input },
                    "OutputLimit" => NumberError::OutputLimit {
                        limit: number("limit"),
                        required: number("required"),
                    },
                    "BufferTooSmall" => NumberError::BufferTooSmall {
                        available: number("available"),
                        required: number("required"),
                    },
                    name => panic!("unknown frozen error {name}"),
                };
                assert_eq!(error, wanted);
                assert!(output.iter().all(|&x| x == 0xa5));
            }
        }
        assert_eq!(&output[..3], &[0xa5; 3]);
    }
}
#[test]
fn every_cap_capacity_pair_for_known_25_byte_span() {
    let input = 0xbec0000000000001;
    let expected = b"-0.0000019073486328125004"; // Independent exact-rational interval oracle.
    assert_eq!(expected.len(), 25);
    for cap in 0..=65 {
        for available in 0..=65 {
            let mut dest = [0x5a; 71];
            let result = format_finite_bits(&input, &mut dest[3..3 + available], cap);
            let error = if cap > 64 {
                Some(NumberError::InvalidLimit {
                    provided: cap,
                    maximum: 64,
                })
            } else if cap < 25 {
                Some(NumberError::OutputLimit {
                    limit: cap,
                    required: 25,
                })
            } else if available < 25 {
                Some(NumberError::BufferTooSmall {
                    available,
                    required: 25,
                })
            } else {
                None
            };
            if let Some(error) = error {
                assert_eq!(result, Err(error));
                assert_eq!(dest, [0x5a; 71]);
            } else {
                assert_eq!(result.unwrap(), expected);
                assert_eq!(&dest[..3], &[0x5a; 3]);
                assert!(dest[28..].iter().all(|&x| x == 0x5a));
            }
        }
    }
}
#[test]
fn nonfinite_payload_and_sign_bits_are_retained_before_capacity() {
    for sign in [0, 1 << 63] {
        for payload in [0, 1, 2, 1 << 51, (1 << 51) + 1, (1 << 52) - 1] {
            let input = sign | 0x7ff0000000000000 | payload;
            for cap in [0, 1, 64] {
                let mut dest = [0x7d; 4];
                assert_eq!(
                    format_finite_bits(&input, &mut dest[..0], cap),
                    Err(NumberError::NonFinite { bits: input })
                );
                assert_eq!(dest, [0x7d; 4]);
            }
        }
    }
    assert_eq!(HARD_MAX_OUTPUT_BYTES, 64);
}
