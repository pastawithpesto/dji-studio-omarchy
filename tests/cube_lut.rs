//! Explicit independent syntax/error fixtures for contract8060eb6a (Astra310).
//! Original edge33/65 acceptance is a separately pinned report-directory harness.
use dji_reframe::cube_lut::{CubeLimits, CubeParseError, parse_cube_subset};

fn limits(input: &[u8], rows: usize) -> CubeLimits {
    CubeLimits {
        max_bytes: input.len(),
        max_rows: rows,
    }
}

#[test]
fn distinct_triples_preserve_encounter_and_component_order() {
    let input = b"# Independent size2 fixture\nLUT_3D_SIZE 2\n\
        1 2 3\n4 5 6\n7 8 9\n10 11 12\n13 14 15\n16 17 18\n19 20 21\n22 23 24\n";
    let table = parse_cube_subset(input, limits(input, 8)).unwrap();
    assert_eq!(table.edge(), 2);
    assert_eq!(
        table.rows(),
        &[
            [1.0, 2.0, 3.0],
            [4.0, 5.0, 6.0],
            [7.0, 8.0, 9.0],
            [10.0, 11.0, 12.0],
            [13.0, 14.0, 15.0],
            [16.0, 17.0, 18.0],
            [19.0, 20.0, 21.0],
            [22.0, 23.0, 24.0],
        ]
    );
}

#[test]
fn observed_separator_styles_and_independent_line_endings() {
    for input in [
        "#\r\n\r\nLUT_3D_SIZE\t1\r\n\r\n0.004309\t0.000291\t0.000241\t\r\n",
        " \t# UTF-8 comment: panorama 🎥\nLUT_3D_SIZE 01\n0 0.000442512 0.000335698\n# end\n",
        "LUT_3D_SIZE 1\n0 0 0",
        "LUT_3D_SIZE 1\r\n\t0 0 0 \t",
    ] {
        let table = parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 1)).unwrap();
        assert_eq!(table.edge(), 1);
        assert_eq!(table.rows().len(), 1);
    }
    let input = b"LUT_3D_SIZE 1\n0.004309\t0.000291\t0.000241\t";
    assert_eq!(
        parse_cube_subset(input, limits(input, 1)).unwrap().rows(),
        &[[0.004309, 0.000291, 0.000241]]
    );
}

#[test]
fn independent_numeric_extensions_do_not_clamp_or_normalize() {
    let input = b"LUT_3D_SIZE 1\n.125 +1. -2E+1";
    assert_eq!(
        parse_cube_subset(input, limits(input, 1)).unwrap().rows(),
        &[[0.125, 1.0, -20.0]]
    );
    let zeros = b"LUT_3D_SIZE 1\n-0 -1e-9999 1e-9999";
    let table = parse_cube_subset(zeros, limits(zeros, 1)).unwrap();
    assert_eq!(table.rows()[0].map(f64::to_bits), [1 << 63, 1 << 63, 0]);
}

#[test]
fn exact_byte_and_row_limits_accept_and_one_less_rejects() {
    let input = b"# counts toward byte limit\nLUT_3D_SIZE 1\n1 2 3\n";
    assert!(parse_cube_subset(input, limits(input, 1)).is_ok());
    assert_eq!(
        parse_cube_subset(
            input,
            CubeLimits {
                max_bytes: input.len() - 1,
                max_rows: 1
            }
        ),
        Err(CubeParseError::InputTooLarge {
            actual: input.len(),
            limit: input.len() - 1
        })
    );
    assert_eq!(
        parse_cube_subset(input, limits(input, 0)),
        Err(CubeParseError::RowLimitExceeded {
            line: 2,
            required: 1,
            limit: 0
        })
    );
    let header_only = b"LUT_3D_SIZE 2\n";
    assert_eq!(
        parse_cube_subset(header_only, limits(header_only, 7)),
        Err(CubeParseError::RowLimitExceeded {
            line: 1,
            required: 8,
            limit: 7
        })
    );
}

#[test]
fn global_byte_then_utf8_errors_precede_line_errors() {
    let input = b"bad header\n# \xff";
    assert_eq!(
        parse_cube_subset(
            input,
            CubeLimits {
                max_bytes: 0,
                max_rows: 0
            }
        ),
        Err(CubeParseError::InputTooLarge {
            actual: input.len(),
            limit: 0
        })
    );
    assert_eq!(
        parse_cube_subset(input, limits(input, 0)),
        Err(CubeParseError::InvalidUtf8)
    );
    assert_eq!(
        parse_cube_subset(b"", limits(b"", 0)),
        Err(CubeParseError::MissingSize)
    );
}

#[test]
fn missing_header_and_data_before_header_are_distinct() {
    let comments = " # valid UTF-8 ✓\n\t\r\n";
    assert_eq!(
        parse_cube_subset(comments.as_bytes(), limits(comments.as_bytes(), 1)),
        Err(CubeParseError::MissingSize)
    );
    let data = b"\n0 0 0\nLUT_3D_SIZE 1\n";
    assert_eq!(
        parse_cube_subset(data, limits(data, 1)),
        Err(CubeParseError::DataBeforeSize { line: 2 })
    );
    let malformed = b"0 nope 0\n";
    assert_eq!(
        parse_cube_subset(malformed, limits(malformed, 1)),
        Err(CubeParseError::InvalidData { line: 1 })
    );
}

#[test]
fn invalid_size_spellings_and_edge_integer_overflow() {
    for token in ["", "0", "+1", "-1", "1.0", "1e0", "1 2"] {
        let input = format!("# comment\nLUT_3D_SIZE {token}\n");
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 1)),
            Err(CubeParseError::InvalidSize { line: 2 }),
            "token {token:?}"
        );
    }
    let input = format!("LUT_3D_SIZE {}0\n", usize::MAX);
    assert_eq!(
        parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), usize::MAX)),
        Err(CubeParseError::InvalidSize { line: 1 })
    );
}

#[test]
fn checked_cube_and_allocation_arithmetic_precede_row_limit() {
    // The first overflows the cube; the second overflows its byte size; the
    // third has a representable byte size above isize::MAX. No allocation occurs.
    let byte_overflow_edge = if usize::BITS == 64 { 1_000_000 } else { 1_000 };
    let isize_overflow_edge = if usize::BITS == 64 { 800_000 } else { 500 };
    for edge in [usize::MAX, byte_overflow_edge, isize_overflow_edge] {
        let input = format!("LUT_3D_SIZE {edge}\n");
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 0)),
            Err(CubeParseError::SizeOverflow { line: 1 })
        );
    }
}

#[test]
fn duplicate_size_precedes_second_declaration_validation_and_row_count() {
    for (input, line) in [
        ("LUT_3D_SIZE 1\nLUT_3D_SIZE 2\n", 2),
        (
            "LUT_3D_SIZE 1\n0 0 0\n# end\nLUT_3D_SIZE nonsense extra\n",
            4,
        ),
    ] {
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 8)),
            Err(CubeParseError::DuplicateSize { line })
        );
    }
}

#[test]
fn unknown_directives_and_inline_comments_are_not_skipped() {
    for record in [
        "TITLE \"name\"",
        "DOMAIN_MIN 0 0 0",
        "DOMAIN_MAX 1 1 1",
        "LUT_1D_SIZE 2",
        "lut_3d_size 1",
        "1 2 3 # inline comment",
        "LUT_3D_SIZE2 1",
    ] {
        let input = format!("LUT_3D_SIZE 1\n{record}\n");
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 1)),
            Err(CubeParseError::InvalidData { line: 2 }),
            "record {record:?}"
        );
    }
    let unsupported = b"TITLE name\n";
    assert_eq!(
        parse_cube_subset(unsupported, limits(unsupported, 1)),
        Err(CubeParseError::InvalidData { line: 1 })
    );
}

#[test]
fn malformed_numeric_arity_grammar_and_nonfinite_values_fail() {
    for record in [
        "1 2",
        "1 2 3 4",
        "NaN 0 0",
        "inf 0 0",
        "-Inf 0 0",
        "1e9999 0 0",
        ". 0 0",
        "+ 0 0",
        "1e 0 0",
        "1e+ 0 0",
        "1e2e3 0 0",
        "1_000 0 0",
        "0x1 0 0",
        "1..0 0 0",
        "1f 0 0",
        "++1 0 0",
    ] {
        let input = format!("LUT_3D_SIZE 1\n{record}\n");
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 1)),
            Err(CubeParseError::InvalidData { line: 2 }),
            "record {record:?}"
        );
    }
}

#[test]
fn bare_cr_control_and_unicode_syntax_fail_including_final_bare_cr() {
    for record in [
        "0 0 0\r",
        "0\r0 0",
        "0\u{b}0 0",
        "0\u{c}0 0",
        "0\u{a0}0 0",
        "０ 0 0",
    ] {
        let input = format!("LUT_3D_SIZE 1\n{record}");
        assert_eq!(
            parse_cube_subset(input.as_bytes(), limits(input.as_bytes(), 1)),
            Err(CubeParseError::InvalidData { line: 2 })
        );
    }
    let header = b"LUT_3D_SIZE 1\r";
    assert_eq!(
        parse_cube_subset(header, limits(header, 1)),
        Err(CubeParseError::InvalidData { line: 1 })
    );
    let bom = b"\xef\xbb\xbfLUT_3D_SIZE 1\n0 0 0";
    assert_eq!(
        parse_cube_subset(bom, limits(bom, 1)),
        Err(CubeParseError::InvalidData { line: 1 })
    );
}

#[test]
fn too_few_and_first_extra_row_have_explicit_counts_and_locations() {
    let short = b"LUT_3D_SIZE 2\n0 0 0\n# only one\n";
    assert_eq!(
        parse_cube_subset(short, limits(short, 8)),
        Err(CubeParseError::RowCountMismatch {
            expected: 8,
            actual: 1,
            line: None
        })
    );
    let extra = b"LUT_3D_SIZE 1\n0 0 0\n# skip\n1 2 3\nmalformed later\n";
    assert_eq!(
        parse_cube_subset(extra, limits(extra, 1)),
        Err(CubeParseError::RowCountMismatch {
            expected: 1,
            actual: 2,
            line: Some(4)
        })
    );
}

#[test]
fn records_after_exact_count_are_still_validated() {
    let comments = b"LUT_3D_SIZE 1\n0 0 0\n\n# valid tail\n";
    assert!(parse_cube_subset(comments, limits(comments, 1)).is_ok());
    let malformed = b"LUT_3D_SIZE 1\n0 0 0\n1 nope 3\n";
    assert_eq!(
        parse_cube_subset(malformed, limits(malformed, 1)),
        Err(CubeParseError::InvalidData { line: 3 })
    );
    let unknown = b"LUT_3D_SIZE 1\n0 0 0\nDOMAIN_MAX 1 1 1\n";
    assert_eq!(
        parse_cube_subset(unknown, limits(unknown, 1)),
        Err(CubeParseError::InvalidData { line: 3 })
    );
}

#[test]
fn returned_table_owns_values_independently_of_input() {
    let mut input = b"LUT_3D_SIZE 1\n1 2 3".to_vec();
    let table = parse_cube_subset(&input, limits(&input, 1)).unwrap();
    input.fill(0);
    assert_eq!(table.rows(), &[[1.0, 2.0, 3.0]]);
}
