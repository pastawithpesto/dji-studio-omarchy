#[path = "../src/mlt/audio.rs"]
mod audio;

use audio::{
    AudioBufferError, mlt_audio_update_volume, mlt_sample_calculator, mlt_sample_calculator_to_now,
};
use serde_json::Value;

fn number(row: &Value, name: &str) -> i64 {
    row[name].as_i64().unwrap()
}

fn float(row: &Value, name: &str) -> f64 {
    let bits = row[name].as_str().unwrap().strip_prefix("0x").unwrap();
    f64::from_bits(u64::from_str_radix(bits, 16).unwrap())
}

#[test]
fn all_original_timing_cases_match_actual_dll_outputs() {
    let cases: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/mlt/audio/original-cases.json")).unwrap();
    let mut counts = [0, 0];
    for row in cases {
        let result = match row["name"].as_str().unwrap() {
            "mlt_sample_calculator_to_now" => {
                counts[0] += 1;
                mlt_sample_calculator_to_now(
                    float(&row, "fps_bits"),
                    number(&row, "frequency") as i32,
                    number(&row, "position"),
                )
            }
            "mlt_sample_calculator" => {
                counts[1] += 1;
                i64::from(mlt_sample_calculator(
                    float(&row, "fps_bits"),
                    number(&row, "frequency") as i32,
                    number(&row, "position"),
                ))
            }
            _ => continue,
        };
        assert_eq!(result, number(&row, "result"), "{row}");
    }
    assert_eq!(counts, [637, 637]);
}

#[test]
fn all_original_volume_cases_match_status_and_each_sample() {
    let cases: Vec<Value> =
        serde_json::from_str(include_str!("fixtures/mlt/audio/original-cases.json")).unwrap();
    let mut count = 0;
    for row in cases {
        if row["name"] != "mlt_audio_update_volume" {
            continue;
        }
        let mut samples = [-32768, 32767, 0, 1, -1, 2, -2, 123, -123, 30000, -30000];
        assert_eq!(
            mlt_audio_update_volume(
                number(&row, "format") as i32,
                &mut samples,
                float(&row, "gain_bits"),
                number(&row, "samples") as i32,
                number(&row, "channels") as i32,
            ),
            Ok(number(&row, "result") as i32),
            "{row}",
        );
        let expected: Vec<i16> = row["output"]
            .as_array()
            .unwrap()
            .iter()
            .map(|value| value.as_i64().unwrap() as i16)
            .collect();
        assert_eq!(samples.as_slice(), expected, "{row}");
        count += 1;
    }
    assert_eq!(count, 90);
}

#[test]
fn safe_bounds_errors_preserve_the_entire_buffer() {
    let mut data = [100, -100, 1000];
    for gain in [0.0, 0.5, f64::NAN] {
        assert_eq!(
            mlt_audio_update_volume(1, &mut data, gain, 2, 2),
            Err(AudioBufferError {
                required_bytes: 8,
                available_bytes: 6,
            }),
        );
        assert_eq!(data, [100, -100, 1000]);
    }
}

#[test]
fn original_bypasses_do_not_reject_unused_counts() {
    let mut data = [i16::MIN, 9];
    assert_eq!(
        mlt_audio_update_volume(1, &mut data, 1.0, i32::MAX, i32::MAX),
        Ok(0),
    );
    assert_eq!(
        mlt_audio_update_volume(2, &mut data, f64::NAN, i32::MAX, i32::MAX),
        Ok(-1),
    );
    assert_eq!(data, [i16::MIN, 9]);
}

#[test]
fn distinct_wrapped_count_paths_preserve_source_byte_arithmetic() {
    let mut data = [9];
    assert_eq!(
        mlt_audio_update_volume(1, &mut data, 0.0, i32::MIN, 1),
        Ok(0),
    );
    assert_eq!(data, [9]);
    assert_eq!(
        mlt_audio_update_volume(1, &mut data, 0.5, i32::MIN, 1),
        Err(AudioBufferError {
            required_bytes: 4_294_967_296,
            available_bytes: 2,
        }),
    );
    assert_eq!(
        mlt_audio_update_volume(1, &mut data, 0.0, -1, 1),
        Err(AudioBufferError {
            required_bytes: 18_446_744_073_709_551_614,
            available_bytes: 2,
        }),
    );
    assert_eq!(data, [9]);
}

#[test]
fn volume_mutates_only_the_requested_prefix() {
    let mut data = [100, -100, i16::MIN];
    assert_eq!(mlt_audio_update_volume(1, &mut data, 0.5, 2, 1), Ok(0));
    assert_eq!(data, [50, -50, i16::MIN]);
    assert_eq!(mlt_audio_update_volume(1, &mut data, 0.0, 1, 1), Ok(0));
    assert_eq!(data, [0, -50, i16::MIN]);
}
