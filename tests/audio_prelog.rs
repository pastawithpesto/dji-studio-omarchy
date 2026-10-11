use dji_reframe::audio_prelog::{Conversion, ConvertError, Level, convert_i16_rms};
use serde_json::Value;

const CORPUS: &str = include_str!("fixtures/audio_prelog/fixtures.json");
// Raw payloads include both zero signs, quiet/signaling NaNs and an infinity.
const MARKERS: [u32; 6] = [
    0x8000_0000,
    0x0000_0000,
    0x7fc0_1234,
    0xffc0_5678,
    0x7f80_0042,
    0x7f80_0000,
];

fn bits(value: &Value) -> u32 {
    u32::from_str_radix(value.as_str().unwrap().strip_prefix("0x").unwrap(), 16).unwrap()
}

fn raw_bits(output: &[f32]) -> Vec<u32> {
    output.iter().map(|value| value.to_bits()).collect()
}

fn fixture(id: &str) -> Value {
    let corpus: Value = serde_json::from_str(CORPUS).unwrap();
    corpus["fixtures"]
        .as_array()
        .unwrap()
        .iter()
        .find(|fixture| fixture["fixture_id"] == id)
        .unwrap()
        .clone()
}

fn input_for(id: &str, count: usize) -> Vec<i16> {
    match id {
        "F1-count0" => Vec::new(),
        "F2-allzero-16000" => vec![0; count],
        "F4-negfullscale-16000" => vec![i16::MIN; count],
        "M2-mixed-22020-27612" => vec![22020, 27612],
        "F6-unit-pulse-16000" => {
            let mut input = vec![0; count];
            input[0] = 1;
            input
        }
        "F7-alternating-pm1-16000" => (0..count)
            .map(|index| if index % 2 == 0 { 1 } else { -1 })
            .collect(),
        _ if id.contains("max32767") => vec![i16::MAX; count],
        _ => panic!("unknown frozen input: {id}"),
    }
}

fn check_fixture(id: &str) {
    let fixture = fixture(id);
    let count = fixture["input"]["count"].as_u64().unwrap() as usize;
    let input = input_for(id, count);
    assert_eq!(input.len(), count);
    let mut output = vec![f32::from_bits(0xffc0_5678); count];
    output.extend(MARKERS.map(f32::from_bits));
    let before = raw_bits(&output);
    let conversion = convert_i16_rms(&input, &mut output).unwrap();
    assert_eq!(conversion.written, count);
    assert_eq!(raw_bits(&output[count..]), MARKERS);

    let expected = &fixture["expected_out"];
    if count == 0 {
        assert_eq!(conversion.level, Level::Empty);
        assert_eq!(raw_bits(&output), before);
        assert_eq!(expected["kind"], "untouched");
        assert_eq!(expected["output_untouched"], true);
        assert_eq!(fixture["output_untouched"], true);
        assert!(fixture["rms_f32_bits"].is_null());
        assert_eq!(fixture["sentinel_branch"], true);
        // Manual extension beyond checker653: original native count0 sentinel
        // load is 138f3 after both loop guards; Rust deliberately returns Empty.
        assert_eq!(bits(&fixture["return"]["bits"]), 0xc2c8_0000);
        assert_eq!(fixture["return"]["value"], -100.0);
        assert_eq!(fixture["return"]["class"], "exact-sentinel");
        return;
    }
    assert_eq!(fixture["output_untouched"], false);
    match expected["kind"].as_str().unwrap() {
        "repeat" => {
            assert_eq!(expected["count"].as_u64().unwrap() as usize, count);
            let expected_bits = bits(&expected["value_bits"]);
            for (index, actual) in output[..count].iter().enumerate() {
                assert_eq!(actual.to_bits(), expected_bits, "{id} sample {index}");
            }
        }
        "literal" => {
            let declared = expected["values_bits"].as_array().unwrap();
            assert!(declared.len() <= count);
            for (index, actual) in output[..count].iter().enumerate() {
                let expected_bits = if index < declared.len() {
                    bits(&declared[index])
                } else {
                    match id {
                        "F6-unit-pulse-16000" => 0x0000_0000,
                        "F7-alternating-pm1-16000" => bits(&declared[index % 2]),
                        _ => panic!("undeclared output: {id}"),
                    }
                };
                assert_eq!(actual.to_bits(), expected_bits, "{id} sample {index}");
            }
        }
        other => panic!("unexpected frozen output kind: {other}"),
    }

    if fixture["sentinel_branch"] == true {
        assert_eq!(conversion.level, Level::Silence);
        // The approved Silence variant has no RMS field. In this frozen case
        // all inputs/outputs are zero, fixing the model RMS at +0; the separate
        // rational oracle verifies that declared RMS, rather than inventing a
        // new public accessor or conflating Silence with DeferredLog.
        assert!(input.iter().all(|&value| value == 0));
        assert!(output[..count].iter().all(|value| value.to_bits() == 0));
        assert_eq!(bits(&fixture["rms_f32_bits"]), 0);
        assert_eq!(bits(&fixture["return"]["bits"]), 0xc2c8_0000);
    } else {
        assert_eq!(
            conversion.level,
            Level::DeferredLog {
                rms_f32_bits: bits(&fixture["rms_f32_bits"])
            }
        );
        // No return/log/analytic_reference_db field is used as a dB oracle.
    }
}

macro_rules! frozen_case {
    ($name:ident, $id:literal) => {
        #[test]
        fn $name() {
            check_fixture($id);
        }
    };
}

frozen_case!(frozen_empty, "F1-count0");
frozen_case!(frozen_silence, "F2-allzero-16000");
frozen_case!(frozen_tail_one, "T1-count1-max32767");
frozen_case!(frozen_tail_two, "T2-count2-max32767");
frozen_case!(frozen_tail_three, "T3-count3-max32767");
frozen_case!(frozen_four, "T4-count4-max32767");
frozen_case!(frozen_four_plus_tail, "T5-count5-max32767");
frozen_case!(frozen_maximum, "F3-count16000-max32767");
frozen_case!(frozen_negative_fullscale, "F4-negfullscale-16000");
frozen_case!(frozen_square_discriminator, "M2-mixed-22020-27612");
frozen_case!(frozen_unit_pulse, "F6-unit-pulse-16000");
frozen_case!(
    frozen_alternating_normalized_samples,
    "F7-alternating-pm1-16000"
);

#[test]
fn corpus_has_exactly_the_twelve_approved_cases_and_manual_m2_fields() {
    let corpus: Value = serde_json::from_str(CORPUS).unwrap();
    let ids: Vec<_> = corpus["fixtures"]
        .as_array()
        .unwrap()
        .iter()
        .map(|fixture| fixture["fixture_id"].as_str().unwrap())
        .collect();
    assert_eq!(corpus["fixture_count"], 12);
    assert_eq!(
        ids,
        [
            "F1-count0",
            "F2-allzero-16000",
            "T1-count1-max32767",
            "T2-count2-max32767",
            "T3-count3-max32767",
            "T4-count4-max32767",
            "T5-count5-max32767",
            "F3-count16000-max32767",
            "F4-negfullscale-16000",
            "M2-mixed-22020-27612",
            "F6-unit-pulse-16000",
            "F7-alternating-pm1-16000",
        ]
    );
    let m2 = fixture("M2-mixed-22020-27612");
    // These fields were outside checker653; reviewed separately against the
    // independent rational oracle. Constant-32767 cases are not discriminators.
    let discriminator = &m2["discriminator"];
    assert_eq!(bits(&discriminator["rounded_square_rms_bits"]), 0x3f43_1a07);
    assert_eq!(bits(&discriminator["exact_square_rms_bits"]), 0x3f43_1a08);
    assert_eq!(discriminator["differ"], true);
    let mut output = [0.0; 2];
    let result = convert_i16_rms(&[22020, 27612], &mut output).unwrap();
    assert_ne!(
        result.level,
        Level::DeferredLog {
            rms_f32_bits: bits(&discriminator["exact_square_rms_bits"])
        }
    );
}

#[test]
fn every_short_capacity_preserves_all_raw_bits_before_any_write() {
    let input = [1, -32768, 32767, 22020, 27612];
    for provided in 0..input.len() {
        let mut output: Vec<_> = MARKERS[..provided]
            .iter()
            .copied()
            .map(f32::from_bits)
            .collect();
        let before = raw_bits(&output);
        assert_eq!(
            convert_i16_rms(&input, &mut output),
            Err(ConvertError::OutputTooSmall {
                needed: input.len(),
                provided
            })
        );
        assert_eq!(raw_bits(&output), before, "capacity {provided}");
    }
}

#[test]
fn empty_preserves_nan_payloads_and_signed_zeros_and_accepts_empty_output() {
    let mut output = MARKERS.map(f32::from_bits);
    let expected = Ok(Conversion {
        written: 0,
        level: Level::Empty,
    });
    assert_eq!(convert_i16_rms(&[], &mut output), expected);
    assert_eq!(raw_bits(&output), MARKERS);
    assert_eq!(convert_i16_rms(&[], &mut []), expected);
}

#[test]
fn silence_writes_positive_zero_prefix_and_preserves_raw_tail() {
    let mut output: Vec<_> = [0x8000_0000; 3]
        .into_iter()
        .chain(MARKERS)
        .map(f32::from_bits)
        .collect();
    assert_eq!(
        convert_i16_rms(&[0, 0, 0], &mut output),
        Ok(Conversion {
            written: 3,
            level: Level::Silence
        })
    );
    assert_eq!(raw_bits(&output[..3]), [0, 0, 0]);
    assert_eq!(raw_bits(&output[3..]), MARKERS);
}

#[test]
fn exhaustive_host_i16_values_and_f64_accumulation_golden_rms_have_no_16000_cap() {
    let input: Vec<_> = (i16::MIN..=i16::MAX).collect();
    let mut output = vec![0.0; input.len()];
    let result = convert_i16_rms(&input, &mut output).unwrap();
    assert_eq!(result.written, 65536);
    // Independent integer/rational RNE oracle: f64 sum gives 3f13cd3a;
    // sequential f32-sum mutant gives 3f13cd1f. This is an analytic fixture,
    // not a Windows observation (see the evidence README).
    assert_eq!(
        result.level,
        Level::DeferredLog {
            rms_f32_bits: 0x3f13_cd3a
        }
    );
    for (&sample, normalized) in input.iter().zip(&output) {
        // Division in f64 is exact for every i16/32768. This checks all signed
        // host values independently of the module's f32 multiplication.
        let exact_normalized = (f64::from(sample) / 32768.0) as f32;
        assert_eq!(normalized.to_bits(), exact_normalized.to_bits());
    }
}

#[test]
fn f64_division_and_sqrt_before_the_f32_rms_round_match_analytic_golden() {
    let mut output = [0.0; 3];
    // Independent rational/Decimal oracle, not generated by the module:
    // rounding the mean to f32 first changes the result to 3efaf4a8.
    assert_eq!(
        convert_i16_rms(&[-9979, -14244, 21712], &mut output),
        Ok(Conversion {
            written: 3,
            level: Level::DeferredLog {
                rms_f32_bits: 0x3efa_f4a7
            }
        })
    );
}
