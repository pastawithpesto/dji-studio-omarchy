//! Independent fixtures pinned by PANO-PLANE-CONTRACT.md (Astra 431).
//! Small expected bits/topology come from pano-plane-analytic-oracle.json;
//! selected large bits use independent exact-integer nearest-even rounding in
//! pano-plane-large-qualification.py/json. No application helper derives them.
//! These checks qualify ordinary native float controls, not vendor runtime.

use dji_reframe::pano_plane::{PanoPlaneError, PanoPlaneGeometry};

#[test]
fn every_reviewed_small_vertex_bit_and_index_matches_independent_fixtures() {
    struct Fixture {
        columns: i32,
        rows: i32,
        vertices: usize,
        x_bits: &'static [u32],
        y_bits: &'static [u32],
        indices: &'static [u32],
    }
    let fixtures = [
        Fixture {
            columns: 2,
            rows: 2,
            vertices: 4,
            x_bits: &[0xbf800000, 0x3f800000],
            y_bits: &[0xbf800000, 0x3f800000],
            indices: &[0, 2, 1, 3],
        },
        Fixture {
            columns: 3,
            rows: 3,
            vertices: 9,
            x_bits: &[0xbf800000, 0, 0x3f800000],
            y_bits: &[0xbf800000, 0, 0x3f800000],
            indices: &[0, 3, 1, 4, 2, 5, 5, 3, 3, 6, 4, 7, 5, 8],
        },
        Fixture {
            columns: 4,
            rows: 2,
            vertices: 8,
            x_bits: &[0xbf800000, 0xbeaaaaaa, 0x3eaaaaac, 0x3f800000],
            y_bits: &[0xbf800000, 0x3f800000],
            indices: &[0, 4, 1, 5, 2, 6, 3, 7],
        },
        Fixture {
            columns: 5,
            rows: 3,
            vertices: 15,
            x_bits: &[0xbf800000, 0xbf000000, 0, 0x3f000000, 0x3f800000],
            y_bits: &[0xbf800000, 0, 0x3f800000],
            indices: &[
                0, 5, 1, 6, 2, 7, 3, 8, 4, 9, 9, 5, 5, 10, 6, 11, 7, 12, 8, 13, 9, 14,
            ],
        },
    ];
    for Fixture {
        columns,
        rows,
        vertices,
        x_bits,
        y_bits,
        indices,
    } in fixtures
    {
        let plane = PanoPlaneGeometry::new(columns, rows).unwrap();
        assert_eq!(
            (plane.columns(), plane.rows()),
            (x_bits.len(), y_bits.len())
        );
        assert_eq!(plane.vertex_count(), vertices);
        assert_eq!(plane.index_count(), indices.len());
        let mut vertex = 0;
        for &y in y_bits {
            for &x in x_bits {
                assert_eq!(
                    plane.vertex_at(vertex).unwrap().map(f32::to_bits),
                    [x, y, 0, 0x3f800000]
                );
                vertex += 1;
            }
        }
        for (index, &expected) in indices.iter().enumerate() {
            assert_eq!(plane.index_at(index), Some(expected));
        }
        for index in [vertices, vertices + 1, usize::MAX] {
            assert_eq!(plane.vertex_at(index), None);
        }
        for index in [indices.len(), indices.len() + 1, usize::MAX] {
            assert_eq!(plane.index_at(index), None);
        }
    }
}

#[test]
fn single_cast_ideal_rational_does_not_replace_original_precision_sequence() {
    let plane = PanoPlaneGeometry::new(4, 2).unwrap();
    let source_bits = plane.vertex_at(1).unwrap()[0].to_bits();
    // Independent exact-rational nearest-even oracle: ideal -1/3 rounds to
    // beaaaaab; f32(1)/f32(3), f64 center/double, f32 rounds to beaaaaaa.
    assert_eq!(source_bits, 0xbeaaaaaa);
    assert_ne!(source_bits, 0xbeaaaaab);
}

#[test]
fn later_row_bands_preserve_both_duplicate_endpoints_at_every_join() {
    let plane = PanoPlaneGeometry::new(2, 4).unwrap();
    // Independent neighboring-row construction extends through band 2.
    let expected = [0, 2, 1, 3, 3, 2, 2, 4, 3, 5, 5, 4, 4, 6, 5, 7];
    assert_eq!(plane.index_count(), expected.len());
    for (index, value) in expected.into_iter().enumerate() {
        assert_eq!(plane.index_at(index), Some(value));
    }
    assert_eq!(
        plane.vertex_at(2),
        Some([-1.0, f32::from_bits(0xbeaaaaaa), 0.0, 1.0])
    );
    assert_eq!(
        plane.vertex_at(5),
        Some([1.0, f32::from_bits(0x3eaaaaac), 0.0, 1.0])
    );
}

#[test]
fn all_small_dimension_signs_and_singletons_precede_size_errors() {
    for invalid in [i32::MIN, -10, -1, 0, 1] {
        for other in [2, i32::MAX] {
            assert_eq!(
                PanoPlaneGeometry::new(invalid, other),
                Err(PanoPlaneError::DimensionTooSmall)
            );
            assert_eq!(
                PanoPlaneGeometry::new(other, invalid),
                Err(PanoPlaneError::DimensionTooSmall)
            );
        }
    }
    assert_eq!(
        PanoPlaneGeometry::new(i32::MAX, 0),
        Err(PanoPlaneError::DimensionTooSmall)
    );
    assert_eq!(
        PanoPlaneGeometry::new(0, i32::MAX),
        Err(PanoPlaneError::DimensionTooSmall)
    );
}

#[test]
fn signed_vertex_and_original_four_times_vertex_overflow_are_rejected() {
    for (columns, rows) in [
        (i32::MAX, 2),
        (2, i32::MAX),
        (65536, 65536),
        (268435456, 2),
        (2, 268435456),
    ] {
        assert_eq!(
            PanoPlaneGeometry::new(columns, rows),
            Err(PanoPlaneError::SizeOverflow)
        );
    }
}

#[test]
fn selected_large_integer_cast_rounding_fixture_needs_no_dense_allocation() {
    let plane = PanoPlaneGeometry::new(16777219, 2).unwrap();
    assert_eq!(
        (
            plane.columns(),
            plane.rows(),
            plane.vertex_count(),
            plane.index_count()
        ),
        (16777219, 2, 33554438, 33554438)
    );
    let points = [
        (0, 0xbf800000),
        (1, 0xbf7ffffe),
        (16777216, 0x3f7ffffc),
        (16777217, 0x3f7ffffc),
        (16777218, 0x3f800000),
    ];
    for (column, x_bits) in points {
        assert_eq!(
            plane.vertex_at(column).unwrap().map(f32::to_bits),
            [x_bits, 0xbf800000, 0, 0x3f800000]
        );
        assert_eq!(
            plane
                .vertex_at(16777219 + column)
                .unwrap()
                .map(f32::to_bits),
            [x_bits, 0x3f800000, 0, 0x3f800000]
        );
    }
    // Position16777217 ties down on its separate binary32 integer cast. An
    // ideal-real single cast instead gives 3f7ffffe, per the saved oracle.
    assert_ne!(plane.vertex_at(16777217).unwrap()[0].to_bits(), 0x3f7ffffe);
    assert_eq!(plane.index_at(0), Some(0));
    assert_eq!(plane.index_at(1), Some(16777219));
    assert_eq!(plane.index_at(33554437), Some(33554437));
    assert_eq!(plane.vertex_at(33554438), None);
    assert_eq!(plane.index_at(33554438), None);
    assert_eq!(plane.vertex_at(usize::MAX), None);
    assert_eq!(plane.index_at(usize::MAX), None);
}

#[cfg(target_pointer_width = "64")]
#[test]
fn last_source_four_times_vertex_boundary_accepts_large_direct_lookups() {
    let plane = PanoPlaneGeometry::new(2, 268435455).unwrap();
    assert_eq!(
        (plane.vertex_count(), plane.index_count()),
        (536870910, 1610612722)
    );
    assert_eq!(plane.vertex_at(536870909), Some([1.0, 1.0, 0.0, 1.0]));
    assert_eq!(plane.index_at(1610612721), Some(536870909));
    assert_eq!(plane.index_at(1610612722), None);
}

#[cfg(target_pointer_width = "32")]
#[test]
fn portable_position_byte_bound_is_checked_without_allocation() {
    // Source4*V fits i32, but 16*V reaches 2^31, beyond 32-bit isize::MAX.
    assert_eq!(
        PanoPlaneGeometry::new(67108864, 2),
        Err(PanoPlaneError::SizeOverflow)
    );
    let last = PanoPlaneGeometry::new(67108863, 2).unwrap();
    assert_eq!(last.vertex_count(), 134217726);
    assert_eq!(last.vertex_at(134217725), Some([1.0, 1.0, 0.0, 1.0]));
    assert_eq!(last.index_at(134217725), Some(134217725));
}
