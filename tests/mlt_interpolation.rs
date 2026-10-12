#[path = "../src/mlt/interpolation.rs"]
mod interpolation;

use serde_json::Value;

const INITIAL_FIXTURES: &str =
    include_str!("fixtures/mlt/interpolation/wine-initial-reference.jsonl");
const EXTENSION_FIXTURES: &str =
    include_str!("fixtures/mlt/interpolation/wine-interpolation-extension.jsonl");

fn rows(source: &str) -> Vec<Value> {
    source
        .lines()
        .map(|line| serde_json::from_str(line).expect("fixture row is valid JSON"))
        .collect()
}

fn bits(field: &Value) -> u64 {
    let text = field.as_str().expect("bit field is a string");
    u64::from_str_radix(text.trim_start_matches("0x"), 16).expect("bit field is hexadecimal")
}

fn apply(name: &str, input: f64) -> f64 {
    match name {
        "mlt_circular_ease_in" => interpolation::mlt_circular_ease_in(input),
        "mlt_cublic_linear_ease_in_out" => interpolation::mlt_cublic_linear_ease_in_out(input),
        "mlt_discrete_interpolation" => interpolation::mlt_discrete_interpolation(input),
        "mlt_linear_interpolation" => interpolation::mlt_linear_interpolation(input),
        "mlt_smooth_interpolation" => interpolation::mlt_smooth_interpolation(input),
        other => panic!("unapproved fixture function: {other}"),
    }
}

#[test]
fn approved_original_wine_rows_match_binary64_bits() {
    let initial = rows(INITIAL_FIXTURES);
    let extension = rows(EXTENSION_FIXTURES);
    assert_eq!(initial.len(), 18);
    assert_eq!(extension.len(), 27);

    let mut asserted = 0;
    let mut excluded_circular = 0;

    for row in initial.iter().chain(extension.iter()) {
        let name = row["name"].as_str().expect("fixture name");
        let input_bits = bits(&row["input_bits"]);
        let expected_bits = bits(&row["output_bits"]);
        let input = f64::from_bits(input_bits);

        if name == "mlt_circular_ease_in" {
            let radicand = 1.0 - input * input;
            if radicand < 0.0 {
                excluded_circular += 1;
                continue;
            }
        }

        let actual_bits = apply(name, input).to_bits();
        assert_eq!(
            actual_bits, expected_bits,
            "{name} input=0x{input_bits:016x}"
        );
        asserted += 1;
    }

    assert_eq!(asserted, 44);
    assert_eq!(excluded_circular, 1);
}
