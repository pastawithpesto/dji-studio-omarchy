#[path = "../src/mlt.rs"]
mod mlt;

use mlt::{
    AudioFormatArithmeticError, mlt_audio_format_name, mlt_audio_format_samples,
    mlt_audio_format_size, mlt_image_format_id, mlt_image_format_name, mlt_image_format_size,
};
use serde_json::Value;

fn baseline() -> Vec<Value> {
    serde_json::from_str(include_str!("fixtures/mlt/formats/original-cases.json")).unwrap()
}

fn additional() -> Vec<Value> {
    serde_json::from_str(include_str!("fixtures/mlt/formats/additional-cases.json")).unwrap()
}

fn integer(row: &Value, field: &str) -> i32 {
    row[field].as_i64().unwrap().try_into().unwrap()
}

fn rax(row: &Value) -> u64 {
    u64::from_str_radix(row["rax"].as_str().unwrap().strip_prefix("0x").unwrap(), 16).unwrap()
}

#[test]
fn original_audio_names_and_sizes_match_the_actual_dll() {
    let mut names = 0;
    let mut sizes = 0;
    for row in baseline() {
        match row["name"].as_str().unwrap() {
            "mlt_audio_format_name" => {
                assert_eq!(mlt_audio_format_name(integer(&row, "format")), row["value"]);
                names += 1;
            }
            "mlt_audio_format_size" => {
                assert_eq!(
                    mlt_audio_format_size(
                        integer(&row, "format"),
                        integer(&row, "first"),
                        integer(&row, "second"),
                    ),
                    rax(&row) as u32 as i32,
                    "{row}",
                );
                sizes += 1;
            }
            _ => {}
        }
    }
    assert_eq!((names, sizes), (11, 350));
}

#[test]
fn original_audio_sample_register_results_match_the_actual_dll() {
    let mut count = 0;
    for row in baseline() {
        if row["name"] == "mlt_audio_format_samples" {
            assert_eq!(
                mlt_audio_format_samples(
                    integer(&row, "format"),
                    integer(&row, "first"),
                    integer(&row, "second"),
                ),
                Ok(rax(&row)),
                "{row}",
            );
            count += 1;
        }
    }
    assert_eq!(count, 349);
}

#[test]
fn original_image_names_sizes_and_optional_output_match_the_actual_dll() {
    let mut names = 0;
    let mut sizes = 0;
    for row in baseline() {
        match row["name"].as_str().unwrap() {
            "mlt_image_format_name" => {
                assert_eq!(mlt_image_format_name(integer(&row, "format")), row["value"]);
                names += 1;
            }
            "mlt_image_format_size" => {
                let mut bpp = 123;
                let result = mlt_image_format_size(
                    integer(&row, "format"),
                    integer(&row, "width"),
                    integer(&row, "height"),
                    Some(&mut bpp),
                );
                assert_eq!(result, rax(&row) as i32, "{row}");
                assert_eq!(bpp, integer(&row, "bpp"), "{row}");
                sizes += 1;
            }
            _ => {}
        }
    }
    assert_eq!((names, sizes), (11, 891));
}

#[test]
fn additional_lookup_and_null_output_cases_match_the_actual_dll() {
    let extras: [&[u8]; 6] = [
        b"",
        b"INVALID",
        b"RGB24",
        b"rgb24_suffix",
        b"rgb24\0suffix",
        b"not-a-format",
    ];
    let mut lookup = 0;
    let mut sizes = 0;
    for row in additional() {
        match row["name"].as_str().unwrap() {
            "mlt_image_format_id" => {
                let input = if row["null"] == true {
                    None
                } else if let Some(index) = row["extra_case"].as_u64() {
                    Some(extras[index as usize])
                } else {
                    Some(row["input"].as_str().unwrap().as_bytes())
                };
                assert_eq!(mlt_image_format_id(input), integer(&row, "value"), "{row}");
                lookup += 1;
            }
            "mlt_image_format_size" => {
                assert_eq!(row["null_bpp"], true);
                assert_eq!(
                    mlt_image_format_size(
                        integer(&row, "format"),
                        integer(&row, "width"),
                        integer(&row, "height"),
                        None,
                    ),
                    rax(&row) as i32,
                    "{row}",
                );
                sizes += 1;
            }
            name => panic!("Unexpected reference API: {name}"),
        }
    }
    assert_eq!((lookup, sizes), (18, 11));
}

#[test]
fn hardware_division_traps_have_explicit_safe_rust_errors() {
    for format in 1..=6 {
        assert_eq!(
            mlt_audio_format_samples(format, 1, 0),
            Err(AudioFormatArithmeticError::DivisionByZero),
        );
    }
    assert_eq!(
        mlt_audio_format_samples(6, i32::MIN, -1),
        Err(AudioFormatArithmeticError::SignedDivisionOverflow),
    );
    for format in [i32::MIN, -1, 0, 7, 8, i32::MAX] {
        assert_eq!(mlt_audio_format_samples(format, 1, 0), Ok(0));
    }
}

#[test]
fn raw_bytes_and_nul_preserve_original_lookup_rules() {
    assert_eq!(mlt_image_format_id(Some(&[0xff, 0xfe])), 8);
    assert_eq!(mlt_image_format_id(Some(b"glsl_texture\0ignored")), 7);
    assert_eq!(mlt_image_format_id(Some(b"glsl_texture_")), 8);
    assert_eq!(mlt_image_format_id(Some(b"invalid")), 8);
}
