//! Synthetic independent Python descriptor fixtures. These are protobuf/schema
//! checks, not camera, Windows or vendor conversion parity tests.
use dji_reframe::metadata::{
    REGISTRATIONS,
    packet::{DecodedPacket, MetadataDecoder, PacketFailureKind},
};
use prost_reflect::{
    Cardinality, DynamicMessage, Kind, ReflectMessage, Value,
    prost::{Message, encoding::WireType},
};
use std::{fs, path::Path};

fn fixture(name: &str) -> Vec<u8> {
    fs::read(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/metadata")
            .join(name),
    )
    .unwrap()
}

fn decoder() -> MetadataDecoder {
    MetadataDecoder::new(4096).unwrap()
}

fn value(message: &DynamicMessage, name: &str) -> Value {
    message.get_field_by_name(name).unwrap().into_owned()
}

fn child<'a>(message: &'a DynamicMessage, name: &str) -> &'a DynamicMessage {
    let (_, value) = message.fields().find(|(f, _)| f.name() == name).unwrap();
    match value {
        Value::Message(message) => message,
        _ => panic!("expected present message {name}"),
    }
}

fn list<'a>(message: &'a DynamicMessage, name: &str) -> &'a [Value] {
    let (_, value) = message.fields().find(|(f, _)| f.name() == name).unwrap();
    match value {
        Value::List(values) => values,
        _ => panic!("expected list {name}"),
    }
}

fn quaternion(message: &DynamicMessage, expected: [f32; 4]) {
    for (component, expected) in ["w", "x", "y", "z"].into_iter().zip(expected) {
        assert_eq!(
            value(message, &format!("quaternion_{component}")),
            Value::F32(expected)
        );
    }
}

fn check_common(packet: &DecodedPacket, filename: &str) {
    let message = packet.message();
    let clip = child(child(message, "clip_meta"), "clip_meta_header");
    assert_eq!(
        value(clip, "proto_file_name"),
        Value::String(filename.into())
    );
    assert_eq!(
        value(clip, "clip_timestamp"),
        Value::U64(18446744073709551613)
    );
    assert_eq!(clip.unknown_fields().next().unwrap().number(), 99);
    let stream = child(message, "stream_meta");
    let pano = child(stream, "pano_dewarp_params");
    let slave = child(pano, "native_refine_slave");
    assert_eq!(value(slave, "fx"), Value::F32(120.5));
    assert_eq!(value(slave, "width"), Value::F32(1920.0));
    assert_eq!(
        list(slave, "p"),
        &[Value::F32(0.125), Value::F32(-0.25), Value::F32(0.5)]
    );
    assert_eq!(
        value(child(pano, "native_refine_master"), "fx"),
        Value::F32(125.5)
    );
    assert_eq!(
        value(child(stream, "extri_lens_mode"), "mode"),
        Value::EnumNumber(1)
    );
    let frame = child(message, "frame_meta");
    let header = child(frame, "frame_meta_header");
    assert_eq!(value(header, "frame_seq_num"), Value::U64(11));
    assert_eq!(
        value(header, "frame_timestamp"),
        Value::U64(9007199254741115)
    );
    assert_eq!(value(header, "stream_id"), Value::U32(2));
    assert_eq!(value(header, "check_code_enable"), Value::Bool(true));
    assert_eq!(value(header, "check_code_type"), Value::EnumNumber(1));
    assert_eq!(value(header, "check_code"), Value::U64(4660));
    let camera = child(frame, "camera_frame_meta");
    let attitude = child(camera, "camera_attitude");
    quaternion(attitude, [1.0, 0.25, -0.5, 0.75]);
    assert_eq!(attitude.unknown_fields().next().unwrap().number(), 99);
    assert_eq!(
        value(
            child(camera, "current_underwater_confidence"),
            "current_underwater_confidence"
        ),
        Value::U32(7)
    );
    let acc = child(camera, "camera_acc");
    for (component, expected) in ["x", "y", "z"].into_iter().zip([1.0, 2.0, 3.0]) {
        assert_eq!(
            value(acc, &format!("accelerometer_{component}")),
            Value::F32(expected)
        );
    }
    let imu = child(frame, "imu_frame_meta");
    let fused = child(imu, "IMU_attitude_after_fusion");
    let current = child(fused, "current_frame");
    assert_eq!(value(current, "timestamp"), Value::U32(4294967294));
    assert_eq!(value(current, "vsync"), Value::U32(5));
    assert_eq!(value(current, "offset"), Value::F32(0.125));
    let attitudes = list(current, "attitude");
    assert_eq!(attitudes.len(), 2);
    for (attitude, expected) in attitudes
        .iter()
        .zip([[1.0, 0.25, -0.5, 0.75], [-1.0, 0.0, 0.5, -0.25]])
    {
        match attitude {
            Value::Message(message) => quaternion(message, expected),
            _ => panic!("expected repeated quaternion"),
        }
    }
    assert_eq!(
        value(child(fused, "prev_frame"), "timestamp"),
        Value::U32(2)
    );
    assert_eq!(
        value(child(fused, "next_frame"), "timestamp"),
        Value::U32(3)
    );
    assert_eq!(
        value(child(imu, "IMU_vsync_pos"), "vsync_pos"),
        Value::U32(17)
    );
}

#[test]
fn descriptor_fixtures_decode_without_time_or_coordinate_conversion() {
    let decoder = decoder();
    for (encoder, package, filename) in [
        ("DJI Osmo360", "oqb101", "dvtm_oqb101.proto"),
        ("Osmo 360 II", "wab530", "dvtm_eagle4_wab530.proto"),
    ] {
        let bytes = fixture(&format!("{package}-complete.pb"));
        let packet = decoder.decode(encoder, bytes.clone()).unwrap();
        assert_eq!(packet.original_packet(), bytes);
        assert_eq!(packet.registration().package, package);
        assert_eq!(
            packet.message().descriptor().full_name(),
            format!("{package}.ProductMeta")
        );
        check_common(&packet, filename);
        let imu = child(child(packet.message(), "frame_meta"), "imu_frame_meta");
        if package == "wab530" {
            let single = child(imu, "IMU_single_attitude_after_fusion");
            assert_eq!(value(single, "timestamp"), Value::U32(78));
            let Value::Message(attitude) = &list(single, "attitude")[0] else {
                panic!()
            };
            quaternion(attitude, [-1.0, 0.0, 0.5, -0.25]);
            let raw = child(imu, "IMU_single_attitude_raw_data");
            assert_eq!(value(raw, "timestamp"), Value::U64(9007199254741191));
            let samples = list(raw, "imu_raw_data");
            assert_eq!(samples.len(), 1);
            let Value::Message(sample) = &samples[0] else {
                panic!()
            };
            for (field, expected) in ["gyro_x", "gyro_y", "gyro_z", "acc_x", "acc_y", "acc_z"]
                .into_iter()
                .zip([0.125, 0.25, 0.5, 1.25, 1.5, 1.75])
            {
                assert_eq!(value(sample, field), Value::F32(expected));
            }
        } else {
            assert!(
                imu.descriptor()
                    .get_field_by_name("IMU_single_attitude_after_fusion")
                    .is_none()
            );
        }
        assert_eq!(packet.into_original_packet(), bytes);
    }
}

#[test]
fn exact_descriptors_retain_schema_differences_and_singular_frame_type() {
    for (encoder, pano, extri, attitude) in [("Osmo 360", 6, 7, 9), ("Osmo 360 II", 5, 6, 22)] {
        let packet = decoder().decode(encoder, Vec::new()).unwrap();
        let product = packet.message().descriptor();
        let frame = product.get_field(3).unwrap();
        assert_eq!(frame.name(), "frame_meta");
        assert_eq!(frame.cardinality(), Cardinality::Optional);
        assert!(frame.supports_presence());
        let Kind::Message(stream) = product.get_field(2).unwrap().kind() else {
            panic!()
        };
        assert_eq!(
            stream
                .get_field_by_name("pano_dewarp_params")
                .unwrap()
                .number(),
            pano
        );
        assert_eq!(
            stream
                .get_field_by_name("extri_lens_mode")
                .unwrap()
                .number(),
            extri
        );
        let Kind::Message(frame) = frame.kind() else {
            panic!()
        };
        let Kind::Message(camera) = frame.get_field(2).unwrap().kind() else {
            panic!()
        };
        let field = camera.get_field_by_name("camera_attitude").unwrap();
        assert_eq!(field.number(), attitude);
        let Kind::Message(quaternion) = field.kind() else {
            panic!()
        };
        for (number, name) in [
            (1, "quaternion_w"),
            (2, "quaternion_x"),
            (3, "quaternion_y"),
            (4, "quaternion_z"),
        ] {
            let field = quaternion.get_field(number).unwrap();
            assert_eq!(field.name(), name);
            assert_eq!(field.kind(), Kind::Float);
        }
    }
}

#[test]
fn all_relevant_exact_aliases_dispatch_and_other_packages_are_explicit() {
    let decoder = decoder();
    let mut supported = 0;
    for registration in REGISTRATIONS {
        let result = decoder.decode(registration.encoder, fixture("empty-frame.pb"));
        if ["oqb101", "wab530"].contains(&registration.package) {
            let packet = result.unwrap();
            assert_eq!(packet.registration(), *registration);
            supported += 1;
        } else {
            let failure = result.unwrap_err();
            assert!(
                matches!(failure.kind(), PacketFailureKind::UnsupportedSchema(actual) if actual == registration)
            );
            assert_eq!(failure.into_original_packet(), fixture("empty-frame.pb"));
        }
    }
    assert_eq!(supported, 10);
    for encoder in ["osmo 360", "Osmo 360 ", "", "unknown camera"] {
        let failure = decoder
            .decode(encoder, fixture("malformed-tail.pb"))
            .unwrap_err();
        assert!(
            matches!(failure.kind(), PacketFailureKind::UnknownEncoder(actual) if actual == encoder)
        );
        assert_eq!(failure.into_original_packet(), fixture("malformed-tail.pb"));
    }
}

#[test]
fn message_presence_and_partial_packets_do_not_require_all_sections() {
    for encoder in ["Osmo 360", "Osmo 360 II"] {
        let decoder = decoder();
        let empty = decoder.decode(encoder, fixture("empty.pb")).unwrap();
        for name in ["clip_meta", "stream_meta", "frame_meta"] {
            assert!(!empty.message().has_field_by_name(name));
        }
        let explicit = decoder.decode(encoder, fixture("empty-frame.pb")).unwrap();
        assert!(explicit.message().has_field_by_name("frame_meta"));
        assert!(!child(explicit.message(), "frame_meta").has_field_by_name("frame_meta_header"));
        let package = explicit.registration().package;
        for section in ["clip_meta", "stream_meta", "frame_meta"] {
            let bytes = fixture(&format!("{package}-{section}-only.pb"));
            let packet = decoder.decode(encoder, bytes.clone()).unwrap();
            assert_eq!(packet.original_packet(), bytes);
            for name in ["clip_meta", "stream_meta", "frame_meta"] {
                assert_eq!(packet.message().has_field_by_name(name), name == section);
            }
        }
    }
}

#[test]
fn top_level_and_nested_unknown_values_survive_semantic_reencoding() {
    // DynamicMessage equality also compares descriptor-pool identity, so both
    // decodes use this same reusable decoder. Values/unknowns are checked above.
    let decoder = decoder();
    for (encoder, package, filename) in [
        ("Osmo 360", "oqb101", "dvtm_oqb101.proto"),
        ("Osmo 360 II", "wab530", "dvtm_eagle4_wab530.proto"),
    ] {
        let bytes = fixture(&format!("{package}-unknown.pb"));
        let packet = decoder.decode(encoder, bytes.clone()).unwrap();
        assert_eq!(packet.original_packet(), bytes);
        let unknown: Vec<_> = packet.message().unknown_fields().collect();
        assert_eq!(
            unknown
                .iter()
                .map(|f| (f.number(), f.wire_type()))
                .collect::<Vec<_>>(),
            [
                (100, WireType::Varint),
                (101, WireType::LengthDelimited),
                (102, WireType::ThirtyTwoBit),
                (103, WireType::SixtyFourBit),
                (104, WireType::StartGroup)
            ]
        );
        let mut encoded_unknown = Vec::new();
        for field in unknown {
            field.encode(&mut encoded_unknown);
        }
        assert_eq!(encoded_unknown, fixture("all-unknown.pb"));
        let encoded = packet.message().encode_to_vec();
        let again = decoder.decode(encoder, encoded).unwrap();
        assert!(
            packet.message() == again.message(),
            "semantic re-encoding lost a value"
        );
        check_common(&again, filename);
    }
    let bytes = fixture("all-unknown.pb");
    let all_unknown = decoder.decode("Osmo 360", bytes.clone()).unwrap();
    assert_eq!(all_unknown.message().unknown_fields().count(), 5);
    assert_eq!(all_unknown.original_packet(), bytes);
    assert!(!all_unknown.message().has_field_by_name("frame_meta"));
}

#[test]
fn original_bytes_remain_authoritative_after_merge_or_noncanonical_encoding() {
    let decoder = decoder();
    for encoder in ["Osmo 360", "Osmo 360 II"] {
        let bytes = fixture("duplicate-frame.pb");
        let packet = decoder.decode(encoder, bytes.clone()).unwrap();
        let header = child(child(packet.message(), "frame_meta"), "frame_meta_header");
        assert_eq!(value(header, "frame_seq_num"), Value::U64(2));
        assert_eq!(value(header, "frame_timestamp"), Value::U64(200));
        assert_eq!(packet.original_packet(), bytes);
        assert_ne!(packet.message().encode_to_vec(), bytes);
    }
    let bytes = fixture("noncanonical-unknown.pb");
    let packet = decoder.decode("Osmo 360", bytes.clone()).unwrap();
    assert_eq!(packet.original_packet(), bytes);
    assert_eq!(packet.message().encode_to_vec(), [0xa0, 0x06, 0xb4, 0x24]);
}

#[test]
fn caller_size_limit_retains_bytes_and_accepts_exact_boundary() {
    let bytes = fixture("empty-frame.pb");
    let failure = MetadataDecoder::new(bytes.len() - 1)
        .unwrap()
        .decode("Osmo 360", bytes.clone())
        .unwrap_err();
    assert!(matches!(
        failure.kind(),
        PacketFailureKind::PacketTooLarge {
            limit: 1,
            actual: 2
        }
    ));
    assert_eq!(failure.into_original_packet(), bytes);
    assert!(
        MetadataDecoder::new(2)
            .unwrap()
            .decode("Osmo 360", bytes)
            .is_ok()
    );
    assert!(
        MetadataDecoder::new(0)
            .unwrap()
            .decode("Osmo 360", Vec::new())
            .is_ok()
    );
}

#[test]
fn malformed_complete_buffers_fail_without_partial_success_or_byte_loss() {
    // Python agrees on syntax failures except its lenient overflow-varint parse;
    // see fixture manifest. Wrong-wire rejection and depth guard below are the
    // pinned native runtime policy, not observed vendor behavior.
    for name in [
        "truncated-key",
        "zero-key",
        "reserved-wire6",
        "reserved-wire7",
        "truncated-varint",
        "overflow-varint",
        "truncated-message",
        "invalid-nested-key",
        "invalid-utf8",
        "malformed-tail",
        "overflow-length",
        "mismatched-group",
        "unclosed-group",
        "unexpected-end-group",
        "recursive-groups101",
        "known-wrong-wire",
    ] {
        let bytes = fixture(&format!("{name}.pb"));
        for encoder in ["Osmo 360", "Osmo 360 II"] {
            let failure = decoder().decode(encoder, bytes.clone()).expect_err(name);
            assert!(
                matches!(failure.kind(), PacketFailureKind::InvalidProtobuf(_)),
                "{name}: {failure}"
            );
            assert_eq!(failure.original_packet(), bytes, "{name}");
            assert_eq!(failure.into_original_packet(), bytes, "{name}");
        }
    }
}
