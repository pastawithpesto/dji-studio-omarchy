use dji_reframe::project_dom::{DomError, DomLimits, DomValue, LimitField, serialize, signature};
use serde_json::Value;

fn corpus(text: &str) -> Value {
    serde_json::from_str(text).unwrap()
}

fn hex(text: &str) -> Vec<u8> {
    assert_eq!(text.len() % 2, 0);
    text.as_bytes()
        .as_chunks::<2>()
        .0
        .iter()
        .map(|pair| {
            let digit = |b: u8| match b {
                b'0'..=b'9' => b - b'0',
                b'a'..=b'f' => b - b'a' + 10,
                _ => panic!("fixture hex digit"),
            };
            (digit(pair[0]) << 4) | digit(pair[1])
        })
        .collect()
}

fn usize_field(value: &Value) -> usize {
    usize::try_from(value.as_u64().unwrap()).unwrap()
}

#[derive(Debug, PartialEq, Eq)]
enum ConstructionError {
    InvalidUtf8,
    UnsupportedKind,
    UnsupportedFields,
    WriterOptions,
}

// Test-only adaptation of frozen typed fixture definitions. Object pairs stay
// ordered; unknown fields/options are rejected instead of silently erased.
fn typed(node: &Value) -> Result<DomValue, ConstructionError> {
    let kind = node["kind"]
        .as_str()
        .ok_or(ConstructionError::UnsupportedKind)?;
    let field = match kind {
        "Null" => None,
        "Bool" | "String" => Some("value"),
        "I64" | "U64" => Some("decimal"),
        "Utf8" | "F64Bits" => Some("hex"),
        "Array" => Some("elements"),
        "Object" => Some("pairs"),
        _ => return Err(ConstructionError::UnsupportedKind),
    };
    if node
        .as_object()
        .ok_or(ConstructionError::UnsupportedKind)?
        .keys()
        .any(|key| key != "kind" && Some(key.as_str()) != field)
    {
        return Err(ConstructionError::UnsupportedFields);
    }
    Ok(match kind {
        "Null" => DomValue::Null,
        "Bool" => DomValue::Bool(node["value"].as_bool().unwrap()),
        "I64" => DomValue::I64(node["decimal"].as_str().unwrap().parse().unwrap()),
        "U64" => DomValue::U64(node["decimal"].as_str().unwrap().parse().unwrap()),
        "String" => DomValue::String(node["value"].as_str().unwrap().to_owned()),
        "Utf8" => DomValue::String(
            String::from_utf8(hex(node["hex"].as_str().unwrap()))
                .map_err(|_| ConstructionError::InvalidUtf8)?,
        ),
        "F64Bits" => {
            DomValue::F64Bits(u64::from_str_radix(node["hex"].as_str().unwrap(), 16).unwrap())
        }
        "Array" => DomValue::Array(
            node["elements"]
                .as_array()
                .unwrap()
                .iter()
                .map(typed)
                .collect::<Result<_, _>>()?,
        ),
        "Object" => DomValue::Object(
            node["pairs"]
                .as_array()
                .unwrap()
                .iter()
                .map(|pair| Ok((pair[0].as_str().unwrap().to_owned(), typed(&pair[1])?)))
                .collect::<Result<_, _>>()?,
        ),
        _ => unreachable!(),
    })
}

fn definition(case: &Value) -> Result<DomValue, ConstructionError> {
    if case.get("writer_options").is_some() {
        return Err(ConstructionError::WriterOptions);
    }
    typed(&case["input"])
}

fn generated(node: &Value) -> DomValue {
    match node["generator"].as_str() {
        None => typed(node).unwrap(),
        Some("singleton_array_chain") => {
            let mut value = typed(&node["leaf"]).unwrap();
            for _ in 0..usize_field(&node["levels"]) {
                value = DomValue::Array(vec![value]);
            }
            value
        }
        Some("array_repeat") => DomValue::Array(
            (0..usize_field(&node["count"]))
                .map(|_| typed(&node["element"]).unwrap())
                .collect(),
        ),
        Some("object_repeat") => DomValue::Object(
            (0..usize_field(&node["count"]))
                .map(|_| {
                    (
                        node["key"].as_str().unwrap().to_owned(),
                        typed(&node["value"]).unwrap(),
                    )
                })
                .collect(),
        ),
        Some("string_repeat") => DomValue::String(
            node["text"]
                .as_str()
                .unwrap()
                .repeat(usize_field(&node["count"])),
        ),
        Some(kind) => panic!("unknown fixture generator {kind}"),
    }
}

fn limits(override_fields: &Value) -> DomLimits {
    let mut result = DomLimits::default();
    if let Some(map) = override_fields.as_object() {
        for (field, value) in map {
            match field.as_str() {
                "max_output_bytes" => result.max_output_bytes = usize_field(value),
                "max_depth" => result.max_depth = usize_field(value),
                "max_records" => result.max_records = usize_field(value),
                _ => panic!("unknown limits field"),
            }
        }
    }
    result
}

fn error(expected: &Value) -> DomError {
    match expected["kind"].as_str().unwrap() {
        "InvalidLimits" => DomError::InvalidLimits {
            field: match expected["field"].as_str().unwrap() {
                "OutputBytes" => LimitField::OutputBytes,
                "Depth" => LimitField::Depth,
                "Records" => LimitField::Records,
                _ => panic!("unknown limit field"),
            },
            requested: usize_field(&expected["requested"]),
            maximum: usize_field(&expected["maximum"]),
        },
        "DepthLimit" => DomError::DepthLimit {
            limit: usize_field(&expected["limit"]),
            attempted_depth: usize_field(&expected["attempted_depth"]),
        },
        "RecordLimit" => DomError::RecordLimit {
            limit: usize_field(&expected["limit"]),
            attempted_records: usize_field(&expected["attempted_records"]),
        },
        "OutputLimit" => DomError::OutputLimit {
            limit: usize_field(&expected["limit"]),
            attempted_bytes: usize_field(&expected["attempted_bytes"]),
        },
        "UnsupportedReal" => DomError::UnsupportedReal {
            bits: u64::from_str_radix(expected["bits"].as_str().unwrap(), 16).unwrap(),
        },
        "NonFiniteReal" => DomError::NonFiniteReal {
            bits: u64::from_str_radix(expected["bits"].as_str().unwrap(), 16).unwrap(),
        },
        _ => panic!("unexpected integration error"),
    }
}

fn assert_crc(bytes: &[u8], actual: dji_reframe::project_dom::DomSignature, expected: &str) {
    assert_eq!(actual.lower_hex.as_slice(), expected.as_bytes());
    assert_eq!(actual.crc32, u32::from_str_radix(expected, 16).unwrap());
    // Compare the separate raw helper over the exact returned span as well.
    assert_eq!(signature(bytes), actual);
}

#[test]
fn approved_literal_bytes_order_types_and_signatures() {
    let fixtures = corpus(include_str!(
        "fixtures/project_dom/approved-byte-fixtures.json"
    ));
    let cases = fixtures["success"].as_array().unwrap();
    assert_eq!(cases.len(), 23);
    for case in cases {
        let input = definition(case).unwrap();
        let before = format!("{input:?}");
        let result = serialize(&input, DomLimits::default()).unwrap();
        assert_eq!(
            result.bytes,
            hex(case["expected_hex"].as_str().unwrap()),
            "{}",
            case["id"]
        );
        assert_eq!(result.bytes.len(), usize_field(&case["byte_length"]));
        assert_crc(
            &result.bytes,
            result.signature,
            case["crc32_hex"].as_str().unwrap(),
        );
        assert_eq!(format!("{input:?}"), before);
    }
}

#[test]
fn exact_native_caps_counts_and_error_precedence() {
    let fixtures = corpus(include_str!("fixtures/project_dom/bounds-fixtures.json"));
    let cases = fixtures["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 46);
    for case in cases {
        let input = generated(&case["input"]);
        let result = serialize(&input, limits(&case["limits_override"]));
        let expected = &case["expected"];
        if expected["result"] == "error" {
            assert_eq!(result, Err(error(expected)), "{}", case["id"]);
        } else {
            let result = result.unwrap_or_else(|error| panic!("{}: {error}", case["id"]));
            assert_eq!(
                result.bytes.len(),
                usize_field(&expected["byte_length"]),
                "{}",
                case["id"]
            );
            if let Some(text) = expected["expected_hex"].as_str() {
                assert_eq!(result.bytes, hex(text));
            } else {
                let p = &expected["output_pattern"];
                let prefix = p["prefix"].as_str().unwrap().as_bytes();
                let repeat = p["repeat"].as_str().unwrap().as_bytes();
                let suffix = p["suffix"].as_str().unwrap().as_bytes();
                assert!(result.bytes.starts_with(prefix) && result.bytes.ends_with(suffix));
                let middle = &result.bytes[prefix.len()..result.bytes.len() - suffix.len()];
                assert_eq!(middle.len(), repeat.len() * usize_field(&p["count"]));
                assert!(
                    middle
                        .chunks_exact(repeat.len())
                        .all(|chunk| chunk == repeat)
                );
            }
            assert_crc(
                &result.bytes,
                result.signature,
                expected["crc32_hex"].as_str().unwrap(),
            );
        }
    }
}

#[test]
fn all_ten_exclusions_are_errors_or_rejected_construction() {
    let corpus = corpus(include_str!(
        "fixtures/project_dom/approved-byte-fixtures.json"
    ));
    let map =
        serde_json::from_str::<Value>(include_str!("fixtures/project_dom/exclusions-api-map.json"))
            .unwrap();
    let cases = map["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 10);
    for mapping in cases {
        let case = corpus["proposed_native_exclusions"]
            .as_array()
            .unwrap()
            .iter()
            .find(|case| case["id"] == mapping["id"])
            .unwrap();
        if mapping["api_domain"] == "runtime" {
            let input = definition(case).unwrap();
            assert_eq!(
                serialize(&input, DomLimits::default()),
                Err(error(&mapping["expected"])),
                "{}",
                case["id"]
            );
        } else {
            let expected = match case["id"].as_str().unwrap() {
                "invalid-utf8" | "lone-surrogate-utf8" => ConstructionError::InvalidUtf8,
                "raw-dom-fragment" => ConstructionError::UnsupportedKind,
                "tagged-float-precision" => ConstructionError::UnsupportedFields,
                "nondefault-options" => ConstructionError::WriterOptions,
                _ => panic!("unknown construction exclusion"),
            };
            assert_eq!(definition(case), Err(expected));
        }
    }
}

#[test]
fn raw_crc_hashes_every_byte_and_preserves_fixed_hex_width() {
    let fixtures = corpus(include_str!("fixtures/project_dom/raw-crc-fixtures.json"));
    let cases = fixtures["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 6);
    for case in cases {
        let bytes = hex(case["bytes_hex"].as_str().unwrap());
        let result = signature(&bytes);
        assert_eq!(u64::from(result.crc32), case["value"].as_u64().unwrap());
        assert_eq!(
            result.lower_hex.as_slice(),
            case["signature"].as_str().unwrap().as_bytes()
        );
    }
}

#[test]
fn integral_real_boundary_bits_never_use_a_general_float_formatter() {
    // Literal neighbors of the approved integral path, not generated outputs.
    for (bits, text) in [
        (0xc33f_ffff_ffff_ffff, "-9007199254740991.0"),
        (0x4330_0000_0000_0001, "4503599627370497.0"),
    ] {
        let result = serialize(&DomValue::F64Bits(bits), DomLimits::default()).unwrap();
        assert_eq!(result.bytes, text.as_bytes());
    }
    for bits in [
        0x3fef_ffff_ffff_ffff,
        0x3ff0_0000_0000_0001,
        0x4340_0000_0000_0001,
        0x8000_0000_0000_0001,
    ] {
        assert_eq!(
            serialize(&DomValue::F64Bits(bits), DomLimits::default()),
            Err(DomError::UnsupportedReal { bits })
        );
    }
}
