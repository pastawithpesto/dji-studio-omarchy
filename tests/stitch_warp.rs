//! Exact binary-rational fixtures from the approved contract and hand algebra.
//! Expected values do not come from the Rust kernel or its helpers.
//! Path loading keeps this scope independent of library registration.

#[path = "../src/stitch_warp.rs"]
mod stitch_warp;

use stitch_warp::{KernelError, MAX_DIMENSION, WarpCoordinates, WarpInput, warp_coordinates};

fn input() -> WarpInput {
    WarpInput {
        uv: [0.25, 0.5],
        flow_sample: [2.0, -1.0],
        flow_scale: 2.0,
        input_size: [8, 4],
        output_size: [16, 8],
    }
}

#[test]
fn approved_rational_fixture_preserves_unequal_dimensions() {
    // Position [2,2], scaled flow [4,-2], weights 1/2, steps [1/16,1/8].
    assert_eq!(
        warp_coordinates(input()),
        Ok(WarpCoordinates {
            left: [0.0, 0.375],
            right: [0.25, 0.125],
            left_y_valid: true,
            right_y_valid: true,
        })
    );
}

#[test]
fn zero_flow_keeps_inclusive_coordinate_endpoints() {
    for uv in [[0.0, 0.0], [1.0, 1.0], [1.0, 0.0], [0.0, 1.0]] {
        let result = warp_coordinates(WarpInput {
            uv,
            flow_sample: [0.0; 2],
            input_size: [8, 4],
            output_size: [8, 4],
            ..input()
        })
        .unwrap();
        assert_eq!(result.left, uv);
        assert_eq!(result.right, uv);
        assert!(result.left_y_valid && result.right_y_valid);
    }
}

#[test]
fn x_correction_is_single_step_without_modulo_or_clamp() {
    // (0 - 24 * 1/2) / 4 = -3; one addition gives -2.
    // (0 + 24 * 1/2) / 4 = 3; one subtraction gives 2.
    let result = warp_coordinates(WarpInput {
        uv: [0.0, 0.5],
        flow_sample: [24.0, 0.0],
        flow_scale: 1.0,
        input_size: [4, 4],
        output_size: [4, 4],
    })
    .unwrap();
    assert_eq!(result.left, [-2.0, 0.5]);
    assert_eq!(result.right, [2.0, 0.5]);
    // Reversing the supplied flow reverses the uncorrected displacements.
    let reversed = warp_coordinates(WarpInput {
        flow_sample: [-24.0, 0.0],
        uv: [0.0, 0.5],
        flow_scale: 1.0,
        input_size: [4, 4],
        output_size: [4, 4],
    })
    .unwrap();
    assert_eq!(reversed.left, [2.0, 0.5]);
    assert_eq!(reversed.right, [-2.0, 0.5]);
}

#[test]
fn y_validity_includes_boundaries_and_preserves_outside_values() {
    // At y=1/2 with unit dimensions, flow 1 gives y=0 and y=1.
    for (flow, expected, valid) in [
        (1.0, [0.0, 1.0], true),
        (2.0, [-0.5, 1.5], false),
        (-2.0, [1.5, -0.5], false),
    ] {
        let result = warp_coordinates(WarpInput {
            uv: [0.0, 0.5],
            flow_sample: [0.0, flow],
            flow_scale: 1.0,
            input_size: [1, 1],
            output_size: [1, 1],
        })
        .unwrap();
        assert_eq!([result.left[1], result.right[1]], expected);
        assert_eq!([result.left_y_valid, result.right_y_valid], [valid; 2]);
    }
}

#[test]
fn dimension_policy_checks_both_sizes_and_accepts_exact_float_limit() {
    for size in [[0, 1], [1, 0], [MAX_DIMENSION + 1, 1], [1, u32::MAX]] {
        assert_eq!(
            warp_coordinates(WarpInput {
                input_size: size,
                ..input()
            }),
            Err(KernelError::InvalidDimensions)
        );
        assert_eq!(
            warp_coordinates(WarpInput {
                output_size: size,
                ..input()
            }),
            Err(KernelError::InvalidDimensions)
        );
    }
    let result = warp_coordinates(WarpInput {
        uv: [1.0, 1.0],
        flow_sample: [0.0; 2],
        input_size: [MAX_DIMENSION; 2],
        output_size: [MAX_DIMENSION; 2],
        ..input()
    })
    .unwrap();
    assert_eq!(result.left, [1.0; 2]);
    assert_eq!(result.right, [1.0; 2]);
}

#[test]
fn nonfinite_values_are_rejected_in_every_supplied_scalar() {
    for bad in [f32::NAN, f32::INFINITY, f32::NEG_INFINITY] {
        for axis in 0..2 {
            let mut candidate = input();
            candidate.uv[axis] = bad;
            assert_eq!(
                warp_coordinates(candidate),
                Err(KernelError::NonFiniteInput)
            );
            let mut candidate = input();
            candidate.flow_sample[axis] = bad;
            assert_eq!(
                warp_coordinates(candidate),
                Err(KernelError::NonFiniteInput)
            );
        }
        assert_eq!(
            warp_coordinates(WarpInput {
                flow_scale: bad,
                ..input()
            }),
            Err(KernelError::NonFiniteInput)
        );
    }
}

#[test]
fn uv_domain_and_error_precedence_follow_declared_native_policy() {
    for uv in [[-0.125, 0.5], [1.125, 0.5], [0.5, -0.125], [0.5, 1.125]] {
        assert_eq!(
            warp_coordinates(WarpInput { uv, ..input() }),
            Err(KernelError::InvalidDomain)
        );
    }
    assert_eq!(
        warp_coordinates(WarpInput {
            input_size: [0, 1],
            uv: [f32::NAN, 2.0],
            ..input()
        }),
        Err(KernelError::InvalidDimensions)
    );
    assert_eq!(
        warp_coordinates(WarpInput {
            uv: [2.0, 0.5],
            flow_scale: f32::INFINITY,
            ..input()
        }),
        Err(KernelError::NonFiniteInput)
    );
}

#[test]
fn finite_input_overflow_returns_no_partial_coordinates() {
    for uv in [[0.5, 0.5], [0.0, 0.0], [1.0, 1.0]] {
        assert_eq!(
            warp_coordinates(WarpInput {
                uv,
                flow_sample: [f32::MAX, 0.0],
                flow_scale: 2.0,
                ..input()
            }),
            Err(KernelError::NonFiniteResult)
        );
    }
}
