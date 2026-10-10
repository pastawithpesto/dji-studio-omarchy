//! Independent fixtures from the reviewed lattice contract and hand algebra.
//! See sol-calibration-review/resumed-projection-20261010/analytic-fixtures.json
//! and analytic-oracle.py. No expected point is produced by application helpers.
//! These are bounded native math checks, not camera or Windows reference outputs.

use dji_reframe::calibration::{
    Model8Calibration, ProjectionOutcome, RawProjectionOptions, RectifiedCamera,
    project_raw_scalar, rotate_ray_row_major, unproject_rectified_fisheye,
};
use dji_reframe::calibration_grid::{GridGeometryError, RectifiedGrid};

#[test]
fn nondivisible_unequal_steps_preserve_explicit_row_major_points() {
    let grid = RectifiedGrid::new([10, 7], [4, 3]).unwrap();
    assert_eq!(
        (grid.columns(), grid.rows(), grid.vertex_count()),
        (3, 3, 9)
    );
    let expected = [
        [0.0, 0.0],
        [4.0, 0.0],
        [8.0, 0.0],
        [0.0, 3.0],
        [4.0, 3.0],
        [8.0, 3.0],
        [0.0, 6.0],
        [4.0, 6.0],
        [8.0, 6.0],
    ];
    for (index, pixel) in expected.into_iter().enumerate() {
        assert_eq!(grid.pixel_at(index), Some(pixel));
    }
    assert_eq!(grid.pixel_at(9), None);
    assert_eq!(grid.pixel_at(usize::MAX), None);
}

#[test]
fn divisible_extents_include_boundary_and_larger_steps_have_one_point() {
    let grid = RectifiedGrid::new([8, 6], [4, 3]).unwrap();
    assert_eq!(
        (grid.columns(), grid.rows(), grid.vertex_count()),
        (3, 3, 9)
    );
    assert_eq!(grid.pixel_at(8), Some([8.0, 6.0]));
    let single = RectifiedGrid::new([8, 6], [9, 7]).unwrap();
    assert_eq!(
        (single.columns(), single.rows(), single.vertex_count()),
        (1, 1, 1)
    );
    assert_eq!(single.pixel_at(0), Some([0.0, 0.0]));
    assert_eq!(single.pixel_at(1), None);
}

#[test]
fn positive_domain_and_error_precedence_are_explicit() {
    for extent in [[0, 1], [1, 0], [-1, 1], [1, i32::MIN]] {
        assert_eq!(
            RectifiedGrid::new(extent, [1, 1]),
            Err(GridGeometryError::NonPositiveExtent)
        );
    }
    for step in [[0, 1], [1, 0], [-1, 1], [1, i32::MIN]] {
        assert_eq!(
            RectifiedGrid::new([1, 1], step),
            Err(GridGeometryError::NonPositiveStep)
        );
    }
    assert_eq!(
        RectifiedGrid::new([0, i32::MAX], [0, 1]),
        Err(GridGeometryError::NonPositiveExtent)
    );
    assert_eq!(
        RectifiedGrid::new([i32::MAX, 1], [1, 0]),
        Err(GridGeometryError::NonPositiveStep)
    );
}

#[test]
fn signed_quotient_plus_one_overflow_is_rejected() {
    for extent in [[i32::MAX, 1], [1, i32::MAX]] {
        assert_eq!(
            RectifiedGrid::new(extent, [1, 1]),
            Err(GridGeometryError::SizeOverflow)
        );
    }
}

#[cfg(target_pointer_width = "32")]
#[test]
fn vertex_count_overflow_is_rejected_on_32_bit_targets() {
    // 65536 * 65536 = 2^32, outside a 32-bit usize. No allocation is involved.
    assert_eq!(
        RectifiedGrid::new([65535, 65535], [1, 1]),
        Err(GridGeometryError::SizeOverflow)
    );
}

#[test]
fn float_endpoints_can_round_beyond_integer_extent_without_allocation() {
    let grid = RectifiedGrid::new([16777219, 1], [1, 1]).unwrap();
    assert_eq!(grid.columns(), 16777220);
    assert_eq!(grid.rows(), 2);
    assert_eq!(grid.vertex_count(), 33554440);
    // Binary32 spacing is 2 here: midpoint 16777219 ties to even 16777220.
    assert_eq!(grid.pixel_at(16777219), Some([16777220.0, 0.0]));
    assert_eq!(grid.pixel_at(33554439), Some([16777220.0, 1.0]));
}

#[test]
fn separate_casts_are_not_replaced_by_one_cast_after_integer_product() {
    let grid = RectifiedGrid::new([50331651, 1], [3, 1]).unwrap();
    assert_eq!(grid.columns(), 16777218);
    // Column16777217 ties down to16777216 in binary32. Multiplication by3
    // therefore gives exactly50331648. The integer product50331651 would
    // instead round to50331652 if multiplied first and cast only once.
    assert_eq!(grid.pixel_at(16777217), Some([50331648.0, 0.0]));
}

#[test]
fn supplied_scalar_composition_matches_independent_quadrant_two_fixture() {
    let grid = RectifiedGrid::new([10, 7], [4, 3]).unwrap();
    let ray = unproject_rectified_fisheye(
        RectifiedCamera {
            focal: 10.0 / std::f32::consts::PI,
            principal_point: [0.0, 0.0],
        },
        grid.pixel_at(4).unwrap(),
    )
    .unwrap();
    let ray = rotate_ray_row_major([0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0], ray).unwrap();
    let camera = Model8Calibration {
        focal: [10.0, 20.0],
        principal_point: [7.0, 11.0],
        tangential: [0.0, 0.0],
        radial: [0.0; 10],
        radial_count: 0,
        crop: [2.0, 3.0],
    };
    let options = RawProjectionOptions {
        model_selector: 8,
        scale_numerator: 6.0,
        scale_denominator: 3,
        pupil_correction: false,
    };
    let ProjectionOutcome::Pixel(pixel) = project_raw_scalar(&camera, options, ray).unwrap() else {
        panic!("Independent off-axis fixture must assign a pixel");
    };
    // Ideal radius5/f(10/pi) => pi/2. Supplied matrix maps[4/5,3/5,0]
    // to[0,3/5,-4/5], so theta=pi-atan(3/4). Scale/crop then yield
    // [1.5,10theta+2.5]. Constants below come from the saved 80-digit
    // Decimal oracle, not from application helper execution.
    let expected = [1.5_f64, 27.480_915_447_965_09_f64];
    let tolerance = [0.00001_f64, 0.00003_f64];
    for axis in 0..2 {
        assert!(
            (f64::from(pixel[axis]) - expected[axis]).abs() <= tolerance[axis],
            "axis{axis}: actual{} expected{} tolerance{}",
            pixel[axis],
            expected[axis],
            tolerance[axis]
        );
    }
}
