//! Literal expectations from the pre-implementation ui-resource-fixtures.json
//! SHA256 db886effd60d994e7c87fc054ff5a1c9a49f6ac932474eb7d351bbf613e5b827,
//! approved by Astra426. Full original-pack comparisons live outside source Git.

use dji_reframe::ui_resource::{
    MAX_UI_RESOURCE_BYTES, UiResourceDecodeError, decode_ui_resource_bytes,
};

fn fixture_tables() -> ([u8; 64], [u8; 48]) {
    (
        std::array::from_fn(|i| i as u8),
        std::array::from_fn(|i| 128 + i as u8),
    )
}

#[test]
fn literal_positions_distinguish_the_two_wrap_lengths() {
    let (a, b) = fixture_tables();
    let encoded: Vec<u8> = (0..=128).collect();
    let output = decode_ui_resource_bytes(&encoded, &a, &b).unwrap();
    assert_eq!(output.len(), 129);
    for (index, expected) in [
        (0, 128),
        (47, 175),
        (48, 128),
        (63, 143),
        (64, 192),
        (65, 193),
        (127, 207),
        (128, 0),
    ] {
        assert_eq!(output[index], expected, "literal position {index}");
    }
}

#[test]
fn small_complete_literal_outputs_include_high_bit_bytes() {
    let (a, b) = fixture_tables();
    assert_eq!(decode_ui_resource_bytes(&[0xff], &a, &b), Ok(vec![0x7f]));
    assert_eq!(
        decode_ui_resource_bytes(&[0x00, 0xff, 0x80, 0x7f], &a, &b),
        Ok(vec![0x80, 0x7f, 0x00, 0xff])
    );
}

#[test]
fn empty_input_has_the_independent_native_error() {
    assert_eq!(
        decode_ui_resource_bytes(&[], &[0; 64], &[0; 48]),
        Err(UiResourceDecodeError::EmptyInput)
    );
}

#[test]
fn exact_sixteen_mib_cap_is_accepted_and_every_byte_is_transformed() {
    assert_eq!(MAX_UI_RESOURCE_BYTES, 16_777_216);
    let encoded = vec![0xff; 16_777_216];
    let output = decode_ui_resource_bytes(&encoded, &[0x80; 64], &[0; 48]).unwrap();
    assert_eq!(output.len(), encoded.len());
    assert!(output.iter().all(|&byte| byte == 0x7f));
}

#[test]
fn cap_plus_one_is_rejected_with_actual_and_limit() {
    let encoded = vec![0; 16_777_217];
    assert_eq!(
        decode_ui_resource_bytes(&encoded, &[0; 64], &[0; 48]),
        Err(UiResourceDecodeError::InputTooLarge {
            actual: 16_777_217,
            limit: 16_777_216,
        })
    );
}

#[test]
fn borrowed_inputs_are_preserved_and_output_is_fresh() {
    let (a, b) = fixture_tables();
    let encoded: Vec<u8> = (0..=128).collect();
    let original_encoded = encoded.clone();
    let original_a = a;
    let original_b = b;
    let mut output = decode_ui_resource_bytes(&encoded, &a, &b).unwrap();
    assert_ne!(output.as_ptr(), encoded.as_ptr());
    output[0] = 0x55;
    assert_eq!(encoded, original_encoded);
    assert_eq!(a, original_a);
    assert_eq!(b, original_b);
}

#[test]
fn zero_tables_accept_all_byte_values_without_a_resource_header() {
    let encoded: Vec<u8> = (0..=255).collect();
    assert_eq!(
        decode_ui_resource_bytes(&encoded, &[0; 64], &[0; 48]),
        Ok(encoded)
    );
}
