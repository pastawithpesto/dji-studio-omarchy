//! Approved independent descriptor corpus, contract889/919, author924.
//! Full typed observations are from Python descriptors, not this implementation.
//! Malformed/size expectations are native dependency policy, not vendor behavior.
use dji_reframe::metadata::{
    REGISTRATIONS,
    packet::{MetadataDecoder, PacketFailureKind},
};
use prost_reflect::{Cardinality, DynamicMessage, Kind, ReflectMessage, Value, prost::Message};
use serde_json::{Value as Json, json};
use std::{fs, path::Path};

const PACKAGES: [&str; 12] = [
    "acb202", "acb203", "acb204", "hgb212", "oqb101", "wab140", "wab234", "wab341", "wab520",
    "wab521", "wab530", "wmb261",
];

fn fixture(name: &str) -> Vec<u8> {
    fs::read(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/metadata-ten-roots")
            .join(name),
    )
    .unwrap()
}
fn document(name: &str) -> Json {
    serde_json::from_slice(&fixture(name)).unwrap()
}
fn encoder(package: &str) -> &'static str {
    REGISTRATIONS
        .iter()
        .find(|r| r.package == package)
        .unwrap()
        .encoder
}
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
fn unhex(text: &str) -> Vec<u8> {
    assert!(text.len().is_multiple_of(2));
    (0..text.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&text[i..i + 2], 16).unwrap())
        .collect()
}
fn kind_number(kind: &Kind) -> u32 {
    match kind {
        Kind::Double => 1,
        Kind::Float => 2,
        Kind::Int64 => 3,
        Kind::Uint64 => 4,
        Kind::Int32 => 5,
        Kind::Fixed64 => 6,
        Kind::Fixed32 => 7,
        Kind::Bool => 8,
        Kind::String => 9,
        Kind::Message(_) => 11,
        Kind::Bytes => 12,
        Kind::Uint32 => 13,
        Kind::Enum(_) => 14,
        Kind::Sfixed32 => 15,
        Kind::Sfixed64 => 16,
        Kind::Sint32 => 17,
        Kind::Sint64 => 18,
    }
}
fn type_name(kind: &Kind) -> Option<&str> {
    match kind {
        Kind::Message(d) => Some(d.full_name()),
        Kind::Enum(d) => Some(d.full_name()),
        _ => None,
    }
}
fn typed_value(value: &Value) -> Json {
    match value {
        Value::Bool(v) => json!(v),
        Value::I32(v) => json!(v),
        Value::U32(v) => json!(v),
        Value::I64(v) => json!({"integer_decimal": v.to_string()}),
        Value::U64(v) => json!({"integer_decimal": v.to_string()}),
        Value::F32(v) => json!({"float32_bits_le_hex": hex(&v.to_bits().to_le_bytes())}),
        Value::F64(v) => json!({"float64_bits_le_hex": hex(&v.to_bits().to_le_bytes())}),
        Value::String(v) => json!(v),
        Value::Bytes(v) => json!({"bytes_hex":hex(v)}),
        Value::EnumNumber(v) => json!(v),
        Value::Message(v) => typed_tree(v),
        Value::List(v) => Json::Array(v.iter().map(typed_value).collect()),
        Value::Map(_) => panic!("no maps in the approved corpus"),
    }
}
fn typed_tree(message: &DynamicMessage) -> Json {
    let mut fields: Vec<_> = message.fields().map(|(f,v)| json!({
        "name":f.name(), "number":f.number(), "type":kind_number(&f.kind()),
        "label": match f.cardinality() { Cardinality::Optional => 1, Cardinality::Required => 2, Cardinality::Repeated => 3 },
        "type_name":type_name(&f.kind()), "value":typed_value(v)
    })).collect();
    fields.sort_by_key(|f| f["number"].as_u64().unwrap());
    json!({"type":message.descriptor().full_name(), "fields":fields})
}
fn expanded(value: &Json, templates: &Json) -> Json {
    if let Some(name) = value.get("message_type_ref").and_then(Json::as_str) {
        return expanded(&templates[name], templates);
    }
    match value {
        Json::Object(map) => Json::Object(
            map.iter()
                .map(|(k, v)| (k.clone(), expanded(v, templates)))
                .collect(),
        ),
        Json::Array(values) => Json::Array(values.iter().map(|v| expanded(v, templates)).collect()),
        _ => value.clone(),
    }
}
fn child<'a>(message: &'a DynamicMessage, name: &str) -> &'a DynamicMessage {
    match message.fields().find(|(f, _)| f.name() == name).unwrap().1 {
        Value::Message(v) => v,
        _ => panic!("expected message {name}"),
    }
}

#[test]
fn all_108_positive_packets_match_independent_full_typed_trees_and_keep_unknown_bytes() {
    let manifest = document("manifest.json");
    let templates = document("EXPECTED-TYPES.json");
    let decoder = MetadataDecoder::new(64 * 1024).unwrap();
    let mut count = 0;
    assert_eq!(manifest["fixture_count"], 124);
    for case in manifest["fixtures"].as_array().unwrap() {
        let package = case["package"].as_str().unwrap();
        if package == "shared" {
            continue;
        }
        let name = case["file"].as_str().unwrap();
        let bytes = fixture(name);
        assert_eq!(
            bytes.len() as u64,
            case["length"].as_u64().unwrap(),
            "{name}"
        );
        assert_eq!(hex(&bytes), case["wire_hex"], "{name}");
        let packet = decoder.decode(encoder(package), bytes.clone()).unwrap();
        assert_eq!(packet.registration().package, package);
        assert_eq!(packet.original_packet(), bytes, "{name}");
        assert_eq!(
            typed_tree(packet.message()),
            expanded(&case["expected"], &templates),
            "{name}"
        );
        if name.ends_with("-root-unknown.pb") {
            let fields: Vec<_> = packet.message().unknown_fields().collect();
            assert_eq!(
                fields.iter().map(|f| f.number()).collect::<Vec<_>>(),
                [100, 101, 102, 103, 104]
            );
            let mut wire = Vec::new();
            for f in fields {
                f.encode(&mut wire);
            }
            let expected = fs::read(
                Path::new(env!("CARGO_MANIFEST_DIR"))
                    .join("tests/fixtures/metadata/all-unknown.pb"),
            )
            .unwrap();
            assert_eq!(wire, expected, "{name}");
        }
        if name.ends_with("-nested-unknown.pb") {
            let header = child(child(packet.message(), "frame_meta"), "frame_meta_header");
            let fields: Vec<_> = header.unknown_fields().collect();
            assert_eq!(fields.len(), 1);
            assert_eq!(fields[0].number(), 99);
            let mut wire = Vec::new();
            fields[0].encode(&mut wire);
            assert_eq!(hex(&wire), case["nested_unknown_wire_hex"]);
        }
        let encoded = packet.message().encode_to_vec();
        let again = decoder.decode(encoder(package), encoded).unwrap();
        assert_eq!(
            packet.message(),
            again.message(),
            "same-pool semantic reencoding {name}"
        );
        assert_eq!(packet.into_original_packet(), bytes, "{name}");
        count += 1;
    }
    assert_eq!(count, 108);
}

#[test]
fn all_202_reachable_types_and_935_fields_match_the_original_descriptor_catalog() {
    let catalog = document("FIELD-CATALOG.json");
    let decoder = MetadataDecoder::new(0).unwrap();
    let packet = decoder.decode(encoder("acb202"), Vec::new()).unwrap();
    let descriptor = packet.message().descriptor();
    let pool = descriptor.parent_pool();
    let mut field_count = 0;
    for (name, expected) in catalog.as_object().unwrap() {
        let message = pool.get_message_by_name(name).unwrap();
        let mut fields: Vec<_> = message.fields().map(|f| json!({
            "name":f.name(),"number":f.number(),"type":kind_number(&f.kind()),
            "label":match f.cardinality() {Cardinality::Optional=>1,Cardinality::Required=>2,Cardinality::Repeated=>3},
            "type_name":type_name(&f.kind()),"packed":f.is_packed()
        })).collect();
        fields.sort_by_key(|f| f["number"].as_u64().unwrap());
        let mut expected = expected.as_array().unwrap().clone();
        expected.sort_by_key(|f| f["number"].as_u64().unwrap());
        assert_eq!(fields, expected, "{name}");
        field_count += fields.len();
    }
    assert_eq!(catalog.as_object().unwrap().len(), 202);
    assert_eq!(field_count, 935);
    for package in PACKAGES {
        let root = pool
            .get_message_by_name(&format!("{package}.ProductMeta"))
            .unwrap();
        for (number, name, section) in [
            (1, "clip_meta", "ClipMeta"),
            (2, "stream_meta", "StreamMeta"),
            (3, "frame_meta", "FrameMeta"),
        ] {
            let f = root.get_field(number).unwrap();
            assert_eq!(f.name(), name);
            assert_eq!(f.cardinality(), Cardinality::Optional);
            assert!(f.supports_presence());
            let Kind::Message(child) = f.kind() else {
                panic!()
            };
            assert_eq!(child.full_name(), format!("{package}.{section}"));
        }
    }
}

#[test]
fn all_32_aliases_select_exact_package_on_empty_present_and_all_fields_packets() {
    let decoder = MetadataDecoder::new(64 * 1024).unwrap();
    for registration in REGISTRATIONS {
        for suffix in ["empty", "empty-frame", "all-fields"] {
            let bytes = fixture(&format!("{}-{suffix}.pb", registration.package));
            let packet = decoder.decode(registration.encoder, bytes.clone()).unwrap();
            assert_eq!(packet.registration(), *registration);
            assert_eq!(
                packet.message().descriptor().full_name(),
                format!("{}.ProductMeta", registration.package)
            );
            assert_eq!(packet.into_original_packet(), bytes);
        }
    }
    assert_eq!(REGISTRATIONS.len(), 32);
}

#[test]
fn all_192_inherited_malformed_and_depth_cases_reject_the_complete_buffer() {
    let manifest = document("manifest.json");
    let decoder = MetadataDecoder::new(64 * 1024).unwrap();
    let mut count = 0;
    for case in manifest["fixtures"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|c| c["package"] == "shared")
    {
        let name = case["file"].as_str().unwrap();
        let bytes = fixture(name);
        assert_eq!(bytes, unhex(case["wire_hex"].as_str().unwrap()));
        for package in PACKAGES {
            let failure = decoder
                .decode(encoder(package), bytes.clone())
                .expect_err(name);
            assert!(
                matches!(failure.kind(), PacketFailureKind::InvalidProtobuf(_)),
                "{name} {package}: {failure}"
            );
            assert_eq!(failure.original_packet(), bytes);
            assert_eq!(failure.into_original_packet(), bytes);
            count += 1;
        }
    }
    assert_eq!(count, 192);
}

#[test]
fn all_202_approved_error_precedence_and_wire_boundary_cases_retain_bytes() {
    // Literal six-case/alias matrix from ERROR-POLICY-CASES.json (contract889).
    let cases: [(&[u8], usize, &str); 6] = [
        (&[], 0, "Decoded"),
        (&[0x1a, 0], 2, "Decoded"),
        (&[0x1a, 0], 1, "PacketTooLarge"),
        (&[0x1a, 0], 0, "PacketTooLarge"),
        (&[0x0a, 0, 0x80], 3, "InvalidProtobuf"),
        (&[0x0a, 0, 0x80], 2, "PacketTooLarge"),
    ];
    let mut counts = [0; 4];
    for registration in REGISTRATIONS {
        for (bytes, limit, expected) in cases {
            let result = MetadataDecoder::new(limit)
                .unwrap()
                .decode(registration.encoder, bytes.to_vec());
            match (result, expected) {
                (Ok(packet), "Decoded") => {
                    assert_eq!(packet.registration(), *registration);
                    assert_eq!(packet.into_original_packet(), bytes);
                    counts[0] += 1;
                }
                (Err(failure), kind) => {
                    assert_eq!(failure.original_packet(), bytes);
                    match (failure.kind(), kind) {
                        (
                            PacketFailureKind::PacketTooLarge {
                                limit: actual_limit,
                                actual,
                            },
                            "PacketTooLarge",
                        ) => {
                            assert_eq!(*actual_limit, limit);
                            assert_eq!(*actual, bytes.len());
                            counts[1] += 1;
                        }
                        (PacketFailureKind::InvalidProtobuf(_), "InvalidProtobuf") => {
                            counts[2] += 1
                        }
                        _ => panic!("{}: expected {kind}, got {failure}", registration.encoder),
                    }
                    assert_eq!(failure.into_original_packet(), bytes);
                }
                _ => panic!("unexpected success {} {expected}", registration.encoder),
            }
        }
    }
    for encoder in ["", "osmo 360", "Osmo 360 ", "unknown camera", "wab020"] {
        for limit in [0, 3] {
            let bytes = vec![0x0a, 0, 0x80];
            let failure = MetadataDecoder::new(limit)
                .unwrap()
                .decode(encoder, bytes.clone())
                .unwrap_err();
            assert!(
                matches!(failure.kind(),PacketFailureKind::UnknownEncoder(actual) if actual==encoder)
            );
            assert_eq!(failure.original_packet(), bytes);
            assert_eq!(failure.into_original_packet(), bytes);
            counts[3] += 1;
        }
    }
    assert_eq!(counts, [64, 96, 32, 10]);
    assert_eq!(counts.iter().sum::<usize>(), 202);
}
