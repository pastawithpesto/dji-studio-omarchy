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

fn finite_plan() -> Value {
    corpus(include_str!("fixtures/project_dom/finite-lane-v1.json"))
}

// Apply only the reviewed keyed deltas; historical fixture bytes stay frozen.
fn finite_delta<'a>(plan: &'a Value, id: &Value) -> Option<&'a Value> {
    plan["historical_expectation_deltas"]
        .as_array()
        .unwrap()
        .iter()
        .find(|delta| delta["old_id"] == *id)
        .map(|delta| &delta["new"])
}

// The approved composition plan has literal integer `value` fields as well
// as unchanged historical `decimal` definitions. Keep this adapter separate
// from the historical safe-construction/exclusion adapter above.
fn planned_typed(node: &Value) -> DomValue {
    match node["kind"].as_str().unwrap() {
        "I64" if node.get("value").is_some() => DomValue::I64(node["value"].as_i64().unwrap()),
        "U64" if node.get("value").is_some() => DomValue::U64(
            node["value"]
                .as_u64()
                .unwrap_or_else(|| node["value"].as_str().unwrap().parse().unwrap()),
        ),
        "Array" => DomValue::Array(
            node["elements"]
                .as_array()
                .unwrap()
                .iter()
                .map(planned_typed)
                .collect(),
        ),
        "Object" => DomValue::Object(
            node["pairs"]
                .as_array()
                .unwrap()
                .iter()
                .map(|pair| {
                    (
                        pair[0].as_str().unwrap().to_owned(),
                        planned_typed(&pair[1]),
                    )
                })
                .collect(),
        ),
        _ => typed(node).unwrap(),
    }
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
    let plan = finite_plan();
    let cases = fixtures["cases"].as_array().unwrap();
    assert_eq!(cases.len(), 46);
    for case in cases {
        let input = generated(&case["input"]);
        let result = serialize(&input, limits(&case["limits_override"]));
        let expected = finite_delta(&plan, &case["id"]).unwrap_or(&case["expected"]);
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
fn historical_exclusions_apply_only_reviewed_finite_deltas() {
    let corpus = corpus(include_str!(
        "fixtures/project_dom/approved-byte-fixtures.json"
    ));
    let map =
        serde_json::from_str::<Value>(include_str!("fixtures/project_dom/exclusions-api-map.json"))
            .unwrap();
    let cases = map["cases"].as_array().unwrap();
    let plan = finite_plan();
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
            let before = format!("{input:?}");
            if let Some(delta) = finite_delta(&plan, &case["id"]) {
                assert_eq!(delta["result"], "success");
                let result = serialize(&input, DomLimits::default()).unwrap();
                assert_eq!(result.bytes, hex(delta["hex"].as_str().unwrap()));
            } else {
                assert_eq!(
                    serialize(&input, DomLimits::default()),
                    Err(error(&mapping["expected"])),
                    "{}",
                    case["id"]
                );
            }
            assert_eq!(format!("{input:?}"), before);
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
fn preserved_integral_neighbor_literals() {
    // Literal neighbors of the approved integral path, not generated outputs.
    for (bits, text) in [
        (0xc33f_ffff_ffff_ffff, "-9007199254740991.0"),
        (0x4330_0000_0000_0001, "4503599627370497.0"),
    ] {
        let result = serialize(&DomValue::F64Bits(bits), DomLimits::default()).unwrap();
        assert_eq!(result.bytes, text.as_bytes());
    }
}

#[test]
fn all_eighty_independently_pinned_finite_compositions_and_neighbors() {
    let plan = finite_plan();
    let compositions = plan["new_composition_cases"].as_array().unwrap();
    let neighbors = plan["finite_neighbor_delta"].as_array().unwrap();
    assert_eq!(compositions.len(), 76);
    assert_eq!(neighbors.len(), 4);
    assert_eq!(
        plan["historical_expectation_deltas"]
            .as_array()
            .unwrap()
            .len(),
        6
    );
    for case in compositions.iter().chain(neighbors) {
        let input = planned_typed(&case["input"]);
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
fn twenty_five_byte_atom_and_container_punctuation_have_distinct_costs() {
    // Frozen830 independent exact-rational interval oracle, not native output.
    let bits = 0xbec0_0000_0000_0001;
    let text = "-0.0000019073486328125004";
    assert_eq!(text.len(), 25);
    let root = DomValue::F64Bits(bits);
    let array = DomValue::Array(vec![DomValue::I64(1), DomValue::F64Bits(bits)]);
    let object = DomValue::Object(vec![("x".to_owned(), DomValue::F64Bits(bits))]);
    for (input, cap, attempted) in [
        (&root, 24, 25),
        (&array, 2, 3),  // Comma fails before real calculation.
        (&array, 3, 28), // Numeric atom is one whole chunk.
        (&array, 27, 28),
        (&array, 28, 29), // Only the closer fails.
        (&object, 4, 5),  // Colon fails before real calculation.
        (&object, 5, 30),
        (&object, 29, 30),
        (&object, 30, 31),
    ] {
        let before = format!("{input:?}");
        assert_eq!(
            serialize(
                input,
                DomLimits {
                    max_output_bytes: cap,
                    ..DomLimits::default()
                }
            ),
            Err(DomError::OutputLimit {
                limit: cap,
                attempted_bytes: attempted
            })
        );
        assert_eq!(format!("{input:?}"), before);
    }
    for (input, cap, expected) in [
        (&root, 25, text.to_owned()),
        (&array, 29, format!("[1,{text}]")),
        (&object, 31, format!("{{\"x\":{text}}}")),
    ] {
        let result = serialize(
            input,
            DomLimits {
                max_output_bytes: cap,
                ..DomLimits::default()
            },
        )
        .unwrap();
        assert_eq!(result.bytes, expected.as_bytes());
        assert_eq!(result.bytes.len(), cap);
    }
}

#[test]
fn newly_finite_values_preserve_depth_record_and_nonfinite_precedence() {
    let bits = 0x3fe0_0000_0000_0000;
    let input = DomValue::Array(vec![DomValue::F64Bits(bits)]);
    for (max_depth, max_records, expected) in [
        (
            0,
            1,
            DomError::DepthLimit {
                limit: 0,
                attempted_depth: 1,
            },
        ),
        (
            1,
            1,
            DomError::RecordLimit {
                limit: 1,
                attempted_records: 2,
            },
        ),
    ] {
        assert_eq!(
            serialize(
                &input,
                DomLimits {
                    max_depth,
                    max_records,
                    ..DomLimits::default()
                }
            ),
            Err(expected)
        );
    }
    for bits in [
        0x7ff0_0000_0000_0000,
        0xfff0_0000_0000_0000,
        0x7ff0_0000_0000_0001,
        0xfff8_1234_5678_9abc,
    ] {
        let input = DomValue::F64Bits(bits);
        assert_eq!(
            serialize(
                &input,
                DomLimits {
                    max_output_bytes: 0,
                    ..DomLimits::default()
                }
            ),
            Err(DomError::NonFiniteReal { bits })
        );
        assert_eq!(input, DomValue::F64Bits(bits));
        // Earlier container punctuation retains priority over a later NaN.
        assert_eq!(
            serialize(
                &DomValue::Array(vec![input]),
                DomLimits {
                    max_output_bytes: 0,
                    ..DomLimits::default()
                }
            ),
            Err(DomError::OutputLimit {
                limit: 0,
                attempted_bytes: 1
            })
        );
    }
}
