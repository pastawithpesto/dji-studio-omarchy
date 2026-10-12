#[path = "../src/stitching.rs"]
mod stitching;

use stitching::{
    AiDimensionError, BandSamples, BandWeightInput, BandWeights, KernelError, LinearBlendInput,
    band_blend_sample, band_buffer_coordinates, band_weights_at, gaussian_5x5_sample,
    linear_blend_sample, validate_ai_dimensions,
};

fn fixture() -> serde_json::Value {
    serde_json::from_str(include_str!(
        "fixtures/stitching/pipeline/scalar-oracles.json"
    ))
    .expect("the pinned scalar oracle fixture must be valid JSON")
}

fn bits(values: &[f32]) -> Vec<String> {
    values
        .iter()
        .map(|value| format!("{:08x}", value.to_bits()))
        .collect()
}

#[test]
fn linear_blend_matches_independent_exact_case_and_endpoints() {
    let oracle = fixture();
    let output = linear_blend_sample(LinearBlendInput {
        uv_y: 0.5,
        height: 8,
        mask_right: 0.0,
        mask_left: 8.0,
        left: [1.0, 0.0, 0.0, 1.0],
        right: [0.0, 0.0, 1.0, 0.0],
    })
    .unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["linear_exact_output_bits"].clone()).unwrap();
    assert_eq!(bits(&output), expected);

    let at_start = linear_blend_sample(LinearBlendInput {
        uv_y: 0.25,
        height: 8,
        mask_right: 0.0,
        mask_left: 8.0,
        left: [1.0; 4],
        right: [0.0; 4],
    })
    .unwrap();
    assert_eq!(at_start, [1.0; 4]);

    let at_stop = linear_blend_sample(LinearBlendInput {
        uv_y: 0.75,
        height: 8,
        mask_right: 0.0,
        mask_left: 8.0,
        left: [1.0; 4],
        right: [0.0; 4],
    })
    .unwrap();
    assert_eq!(at_stop, [0.0; 4]);
}

#[test]
fn linear_collapsed_height_one_interval_is_not_reclamped() {
    let output = linear_blend_sample(LinearBlendInput {
        uv_y: 0.5,
        height: 1,
        mask_right: -10.0,
        mask_left: 20.0,
        left: [1.0; 4],
        right: [0.0; 4],
    })
    .unwrap();
    assert_eq!(output, [0.5; 4]);
}

#[test]
fn band_weights_match_exact_and_negative_length_cases() {
    let oracle = fixture();
    let exact = band_weights_at(BandWeightInput {
        current_y: 4.0,
        height: 8,
        mask_right: 0.0,
        mask_left: 8.0,
        band_step: 2,
    })
    .unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["band_exact_weight_bits"].clone()).unwrap();
    assert_eq!(bits(&[exact.low_left, exact.high_left]), expected);

    let negative_length = band_weights_at(BandWeightInput {
        current_y: 5.5,
        height: 8,
        mask_right: 6.0,
        mask_left: 2.0,
        band_step: 2,
    })
    .unwrap();
    assert_eq!(
        negative_length,
        BandWeights {
            low_left: 0.5,
            high_left: 0.5
        }
    );
}

#[test]
fn band_step_controls_high_level_and_low_level_caps_at_110() {
    let oracle = fixture();
    let weights = band_weights_at(BandWeightInput {
        current_y: 145.0,
        height: 512,
        mask_right: 0.0,
        mask_left: 400.0,
        band_step: 200,
    })
    .unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["band_low_cap_probe_weight_bits"].clone()).unwrap();
    assert_eq!(bits(&[weights.low_left, weights.high_left]), expected);

    let zero_step = band_weights_at(BandWeightInput {
        current_y: 200.5,
        height: 512,
        mask_right: 0.0,
        mask_left: 400.0,
        band_step: 0,
    })
    .unwrap();
    assert_eq!(zero_step.high_left, 0.5);
}

#[test]
fn buffer_coordinates_clamp_the_right_endpoint_and_preserve_half_texel_offset() {
    let oracle = fixture();
    let coordinates = band_buffer_coordinates([1.0, 0.5], [8, 8]).unwrap();
    assert_eq!(
        coordinates.mask_index,
        oracle["buffer_exact"]["mask_index"].as_u64().unwrap() as usize
    );
    assert_eq!(
        bits(&[coordinates.current_y])[0],
        oracle["buffer_exact"]["current_y_bits"].as_str().unwrap()
    );

    assert_eq!(
        band_buffer_coordinates([0.0, 0.0], [8, 8])
            .unwrap()
            .mask_index,
        0
    );
    assert_eq!(
        band_buffer_coordinates([0.0, 0.0], [8, 8])
            .unwrap()
            .current_y,
        -0.5
    );
}

#[test]
fn band_color_matches_independent_four_component_oracle_without_clamping() {
    let oracle = fixture();
    let result = band_blend_sample(
        BandSamples {
            left: [2.0, 4.0, 6.0, 8.0],
            right: [0.0, 2.0, 4.0, 6.0],
            low_left: [1.0; 4],
            low_right: [0.0; 4],
        },
        BandWeights {
            low_left: 1.0,
            high_left: 0.0,
        },
    )
    .unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["band_color_four_component_output_bits"].clone()).unwrap();
    assert_eq!(bits(&result), expected);
    assert!(result[3] > 1.0);
}

#[test]
fn gaussian_matches_reviewed_constant_and_asymmetric_oracles() {
    let oracle = fixture();
    let constant = gaussian_5x5_sample(&[[1.0; 4]; 25]).unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["gaussian_constant_output_bits"].clone()).unwrap();
    assert_eq!(bits(&constant), expected);

    let rational_samples = [
        0.125, -0.5, 1.125, -2.0, 3.125, -4.5, 6.125, -8.0, 10.125, -12.5, 15.125, -18.0, 21.125,
        -24.5, 28.125, -32.0, 36.125, -40.5, 45.125, -50.0, 55.125, -60.5, 66.125, -72.0, 78.125,
    ];
    let asymmetric = std::array::from_fn(|index| [rational_samples[index]; 4]);
    let result = gaussian_5x5_sample(&asymmetric).unwrap();
    let expected: Vec<String> =
        serde_json::from_value(oracle["gaussian_asymmetric_output_bits"].clone()).unwrap();
    assert_eq!(bits(&result), expected);
}

#[test]
fn ai_dimensions_keep_exact_signed_predicate_and_error_order() {
    assert_eq!(validate_ai_dimensions([1, 1], [1, 1]), Ok(()));
    assert_eq!(
        validate_ai_dimensions([i32::MAX, i32::MAX], [i32::MAX, i32::MAX]),
        Ok(())
    );
    assert_eq!(
        validate_ai_dimensions([0, 1], [9, 9]),
        Err(AiDimensionError::NonPositiveInput)
    );
    assert_eq!(
        validate_ai_dimensions([i32::MIN, 1], [0, 1]),
        Err(AiDimensionError::NonPositiveInput)
    );
    assert_eq!(
        validate_ai_dimensions([1, 2], [2, 1]),
        Err(AiDimensionError::SizeMismatch)
    );
    assert_eq!(
        validate_ai_dimensions([1, 1], [-1, 1]),
        Err(AiDimensionError::SizeMismatch)
    );
}

#[test]
fn dimensions_domains_and_nonfinite_failures_use_the_checked_policy() {
    assert_eq!(
        band_buffer_coordinates([0.5, 0.5], [0, 8]),
        Err(KernelError::InvalidDimensions)
    );
    assert_eq!(
        band_buffer_coordinates([0.5, 0.5], [16_777_217, 8]),
        Err(KernelError::InvalidDimensions)
    );
    assert_eq!(
        band_buffer_coordinates([1.01, 0.5], [8, 8]),
        Err(KernelError::InvalidDomain)
    );
    assert_eq!(
        band_buffer_coordinates([f32::NAN, 0.5], [8, 8]),
        Err(KernelError::NonFiniteInput)
    );
    assert_eq!(
        band_weights_at(BandWeightInput {
            current_y: 1.0,
            height: 8,
            mask_right: 0.0,
            mask_left: 4.0,
            band_step: -1,
        }),
        Err(KernelError::InvalidDomain)
    );
    assert_eq!(
        band_weights_at(BandWeightInput {
            current_y: 1.0,
            height: 8,
            mask_right: 0.0,
            mask_left: 4.0,
            band_step: 16_777_217,
        }),
        Err(KernelError::InvalidDomain)
    );
    assert_eq!(
        linear_blend_sample(LinearBlendInput {
            uv_y: -0.01,
            height: 8,
            mask_right: 0.0,
            mask_left: 8.0,
            left: [0.0; 4],
            right: [1.0; 4],
        }),
        Err(KernelError::InvalidDomain)
    );
    assert_eq!(
        linear_blend_sample(LinearBlendInput {
            uv_y: f32::INFINITY,
            height: 8,
            mask_right: 0.0,
            mask_left: 8.0,
            left: [0.0; 4],
            right: [1.0; 4],
        }),
        Err(KernelError::NonFiniteInput)
    );
    assert_eq!(
        band_blend_sample(
            BandSamples {
                left: [f32::MAX, 0.0, 0.0, 0.0],
                right: [0.0; 4],
                low_left: [-f32::MAX, 0.0, 0.0, 0.0],
                low_right: [0.0; 4],
            },
            BandWeights {
                low_left: 0.5,
                high_left: 0.5
            },
        ),
        Err(KernelError::NonFiniteResult)
    );
}
