//! Pinned independent carrier oracles and explicitly native process/IO policies.
use base64::{Engine, engine::general_purpose::STANDARD};
use dji_reframe::metadata::{
    demux::{
        CarrierOrigin, CleanupKind, DemuxErrorKind, Ffprobe, NestedDisposition, NestedError,
        NestedErrorKind, NestedLimits, NestedMetadata, NestedStage, PacketOutcome, ProbeLimits,
        StreamInfo, inspect_nested,
    },
    packet::PacketFailureKind,
};
use serde_json::{Value, json};
use std::{
    ffi::{CString, OsString},
    fs,
    os::unix::{
        ffi::{OsStrExt, OsStringExt},
        fs::PermissionsExt,
    },
    path::{Path, PathBuf},
    process::{Command, Output, Stdio},
    sync::atomic::{AtomicU64, Ordering},
    thread,
    time::{Duration, Instant},
};

fn fixture(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/nested")
        .join(name)
}
static NEXT: AtomicU64 = AtomicU64::new(0);
struct Temp(PathBuf);
impl Temp {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "dji-nested-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn limits(&self) -> NestedLimits {
        NestedLimits {
            temp_root: self.0.clone(),
            ..NestedLimits::default()
        }
    }
    fn empty(&self) {
        assert_eq!(fs::read_dir(&self.0).unwrap().count(), 0);
    }
}
impl Drop for Temp {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    } // Exclusive test-owned directory only.
}
fn decode_dump(value: &Value) -> Vec<u8> {
    let dump: Vec<u8> = value
        .as_str()
        .unwrap()
        .bytes()
        .filter(|b| !b.is_ascii_whitespace())
        .collect();
    STANDARD.decode(dump).unwrap()
}
fn integer(value: &Value) -> Option<i64> {
    if value.is_null() {
        None
    } else {
        Some(
            value
                .as_i64()
                .unwrap_or_else(|| value.as_str().unwrap().parse().unwrap()),
        )
    }
}
fn position(value: &Value) -> Option<u64> {
    if value.is_null() || value == "-1" || value == "N/A" {
        None
    } else {
        Some(
            value
                .as_u64()
                .unwrap_or_else(|| value.as_str().unwrap().parse().unwrap()),
        )
    }
}
fn assert_streams(actual: &[StreamInfo], expected: &Value) {
    let expected = expected.as_array().unwrap();
    assert_eq!(actual.len(), expected.len());
    for (stream, item) in actual.iter().zip(expected) {
        assert_eq!(stream.index as u64, item["index"].as_u64().unwrap());
        assert_eq!(stream.id.as_deref(), item["id"].as_str());
        assert_eq!(
            stream.codec_tag,
            u32::from_str_radix(
                item["codec_tag"].as_str().unwrap().trim_start_matches("0x"),
                16
            )
            .unwrap()
        );
        assert_eq!(stream.codec_tag_string, item["codec_tag_string"]);
        assert_eq!(
            format!(
                "{}/{}",
                stream.time_base.numerator, stream.time_base.denominator
            ),
            item["time_base"]
        );
    }
}
fn bounded_cli(path: &Path) -> Output {
    let mut child = Command::new(env!("CARGO_BIN_EXE_dji-reframe"))
        .arg("--metadata-nested")
        .arg(path)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let started = Instant::now();
    loop {
        if child.try_wait().unwrap().is_some() {
            return child.wait_with_output().unwrap();
        }
        if started.elapsed() > Duration::from_secs(5) {
            let _ = child.kill();
            let _ = child.wait();
            panic!("owned CLI exceeded deadline");
        }
        thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn all_frozen_carriers_and_separate_first_box_acceptance_match_exact_bytes_and_context() {
    let manifest: Value =
        serde_json::from_slice(&fs::read(fixture("acceptance.json")).unwrap()).unwrap();
    assert_eq!(manifest["cases"].as_array().unwrap().len(), 22);
    for case in manifest["cases"].as_array().unwrap() {
        let name = case["id"].as_str().unwrap();
        let temp = Temp::new();
        let result = inspect_nested(
            &fixture(name),
            &Ffprobe::new("/usr/bin/ffprobe"),
            &ProbeLimits::default(),
            &temp.limits(),
        );
        let cli = bounded_cli(&fixture(name));
        if let Some(expected) = case["error"].as_str() {
            let error = result.unwrap_err();
            assert_eq!(
                error.context.outer.as_ref().unwrap().encoder.as_deref(),
                case["outer_encoder_expected"].as_str()
            );
            match expected {
                "empty" => {
                    assert!(matches!(error.kind, NestedErrorKind::EmptyCarrier));
                    assert!(error.context.carrier.is_none());
                }
                "span" => {
                    assert!(matches!(error.kind, NestedErrorKind::MalformedBox(_)));
                    assert_eq!(error.stage, NestedStage::BoxExtraction);
                    assert!(error.context.carrier.is_none());
                }
                "inner-probe" => {
                    assert!(
                        matches!(error.kind, NestedErrorKind::Probe(ref p) if matches!(p.kind, DemuxErrorKind::Exit(_)))
                    );
                    assert_eq!(error.stage, NestedStage::InnerInventory);
                    assert_eq!(
                        error.context.carrier.as_ref().unwrap().bytes(),
                        decode_dump(&case["carrier_base64"])
                    );
                }
                _ => panic!("unknown expected failure"),
            }
            assert!(error.cleanup.is_none());
            assert!(!cli.status.success(), "{name}");
        } else {
            let report = result.unwrap_or_else(|e| panic!("{name}: {e}"));
            assert_eq!(report.disposition, NestedDisposition::InnerDirectTracks);
            assert_eq!(
                report.outer.encoder.as_deref(),
                case["outer_encoder_expected"].as_str()
            );
            assert_streams(&report.outer.streams, &case["outer_inventory"]["streams"]);
            let carrier = report.carrier.as_ref().unwrap();
            assert_eq!(
                carrier.bytes(),
                decode_dump(&case["carrier_base64"]),
                "{name}"
            );
            match carrier.origin() {
                CarrierOrigin::TopLevelBox {
                    tag,
                    box_offset,
                    header_bytes,
                    payload_offset,
                    payload_len,
                } => {
                    let b = &case["box"];
                    assert_eq!(tag, b["tag"].as_str().unwrap().as_bytes());
                    assert_eq!(*box_offset, b["box_offset"].as_u64().unwrap());
                    assert_eq!(
                        u64::from(*header_bytes),
                        b["header_bytes"].as_u64().unwrap()
                    );
                    assert_eq!(*payload_offset, b["payload_offset"].as_u64().unwrap());
                    assert_eq!(*payload_len, b["payload_length"].as_u64().unwrap());
                }
                CarrierOrigin::CamdStreamParts { stream, parts } => {
                    let indexes = case["camd_indexes"].as_array().unwrap();
                    assert_eq!(Some(stream.index), report.outer.selected_camd_index);
                    assert_eq!(stream.index as u64, indexes[0].as_u64().unwrap());
                    assert_eq!(
                        report.outer.ignored_camd_indexes,
                        indexes
                            .iter()
                            .skip(1)
                            .map(|n| n.as_u64().unwrap() as u32)
                            .collect::<Vec<_>>()
                    );
                    let expected = case["parts"].as_array().unwrap();
                    assert_eq!(parts.len(), expected.len());
                    for (sequence, (part, item)) in parts.iter().zip(expected).enumerate() {
                        assert_eq!(part.sequence, sequence);
                        assert_eq!(part.pts, integer(&item["outer_pts"]));
                        assert_eq!(part.dts, integer(&item["outer_dts"]));
                        assert_eq!(part.outer_source_position, position(&item["outer_pos"]));
                        assert_eq!(
                            part.carrier_offset as u64,
                            item["carrier_offset"].as_u64().unwrap()
                        );
                        assert_eq!(part.length as u64, item["length"].as_u64().unwrap());
                    }
                }
            }
            let inner = report.inner.as_ref().unwrap();
            assert_eq!(
                inner.encoder.as_deref(),
                case["inner_inventory"]["encoder"].as_str()
            );
            assert_streams(&inner.streams, &case["inner_inventory"]["streams"]);
            let probes = case["inner_inventory"]["metadata_packet_probes"]
                .as_array()
                .unwrap();
            assert_eq!(report.tracks.len(), probes.len().min(2));
            for (track, expected) in report.tracks.iter().zip(probes) {
                assert_eq!(
                    track.stream.index as u64,
                    expected["selected_index"].as_u64().unwrap()
                );
                let packets = expected["decoded_packets"].as_array().unwrap();
                assert_eq!(track.packets.len(), packets.len());
                for (packet, item) in track.packets.iter().zip(packets) {
                    assert_eq!(
                        packet.outcome.original_packet(),
                        decode_dump(&item["data_base64"])
                    );
                    assert_eq!(packet.pts, integer(&item["pts"]));
                    assert_eq!(packet.dts, integer(&item["dts"]));
                    assert_eq!(packet.source_position, position(&item["pos"]));
                    if case["transport_mismatch"] != true {
                        let PacketOutcome::Decoded(decoded) = &packet.outcome else {
                            panic!("{name}: matching encoder failed")
                        };
                        assert_eq!(
                            decoded.registration().package,
                            if name.contains("wab530") {
                                "wab530"
                            } else {
                                "oqb101"
                            }
                        );
                    } else if let PacketOutcome::Decoded(decoded) = &packet.outcome {
                        assert_eq!(decoded.registration().package, "oqb101"); // Outer encoder only; no WAB compatibility claim.
                    }
                }
            }
            if case["transport_mismatch"] != true {
                assert!(
                    cli.status.success(),
                    "{name}: {}",
                    String::from_utf8_lossy(&cli.stderr)
                );
            }
            assert!(String::from_utf8_lossy(&cli.stdout).contains("inner_encoder_diagnostic"));
        }
        temp.empty();
    }
}

fn stream(index: u32, tag: &str) -> Value {
    let raw = match tag {
        "camd" => "0x646d6163",
        "djmd" => "0x646d6a64",
        "xtmd" => "0x646d7478",
        _ => "0x31637661",
    };
    json!({"index":index,"id":format!("0x{}",index+1),"codec_tag":raw,"codec_tag_string":tag,"time_base":"1/1000"})
}
fn inventory(encoder: Option<&str>, streams: Vec<Value>) -> Value {
    let mut result = json!({"format":{"tags":{}},"streams":streams});
    if let Some(encoder) = encoder {
        result["format"]["tags"]["encoder"] = json!(encoder);
    }
    result
}
fn packet(index: u32, bytes: &[u8]) -> Value {
    json!({"stream_index":index,"pts":-1,"dts":"144115188075868217","pos":"18446744073709551615","size":bytes.len().to_string(),"data":STANDARD.encode(bytes)})
}
fn box_bytes(tag: &[u8; 4], bytes: &[u8]) -> Vec<u8> {
    let mut result = ((8 + bytes.len()) as u32).to_be_bytes().to_vec();
    result.extend_from_slice(tag);
    result.extend_from_slice(bytes);
    result
}
struct Mock {
    temp: Temp,
    transport: Temp,
    input: PathBuf,
    tool: Ffprobe,
}
impl Mock {
    fn new(outer: Value, inner: Value, inner_packets: Vec<Value>, action: &str) -> Self {
        let temp = Temp::new();
        let transport = Temp::new();
        let input = temp
            .0
            .join(OsString::from_vec(b"-file:input-\xfe.mp4".to_vec()));
        fs::write(&input, box_bytes(b"META", b"independent mock carrier")).unwrap();
        for (name, value) in [
            ("outer", outer),
            ("inner", inner),
            (
                "outer-packets",
                json!({"packets":[packet(3,b"independent mock carrier")]}),
            ),
        ] {
            fs::write(temp.0.join(name), serde_json::to_vec(&value).unwrap()).unwrap();
        }
        for (index, value) in inner_packets.into_iter().enumerate() {
            fs::write(
                temp.0.join(format!("inner-packets-{index}")),
                serde_json::to_vec(&value).unwrap(),
            )
            .unwrap();
        }
        let script = temp.0.join("trusted probe.py");
        let input_hex: String = input
            .as_os_str()
            .as_bytes()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        let source = format!(
            r#"#!/usr/bin/python3
import os,sys,time,json,stat
from pathlib import Path
root=Path(__file__).resolve().parent
with (root/'pids').open('a') as f: f.write(str(os.getpid())+'\n')
args=sys.argv[1:]
p=Path(args[-1])
is_inner=os.fsencode(p)!=bytes.fromhex('{input_hex}')
assert args[-2]=='-i' and p.is_absolute()
assert args[:6]==['-v','error','-protocol_whitelist','file','-of','json=string_validation=fail']
is_packet='-show_packets' in args
index=int(args[args.index('-select_streams')+1]) if is_packet else None
if is_packet:
    assert args[6:-2]==['-select_streams',str(index),'-show_packets','-show_data','-data_dump_format','base64','-show_entries','packet=stream_index,pts,dts,pos,size,data']
else:
    assert args[6:-2]==['-show_entries','format_tags=encoder:stream=index,id,codec_tag,codec_tag_string,time_base']
assert sys.stdin.buffer.read()==b''
if is_inner:
    assert stat.S_IMODE(p.stat().st_mode)==0o600
    assert stat.S_IMODE(p.parent.stat().st_mode)==0o700
    assert p.read_bytes()==b'independent mock carrier'
    data=(root/(('inner-packets-'+str(index)) if is_packet else 'inner')).read_bytes()
else:
    data=(root/('outer-packets' if is_packet else 'outer')).read_bytes()
{action}
sys.stdout.buffer.write(data)
"#
        );
        fs::write(&script, source).unwrap();
        fs::set_permissions(&script, fs::Permissions::from_mode(0o700)).unwrap();
        Self {
            temp,
            transport,
            input,
            tool: Ffprobe::new(script),
        }
    }
    fn standard(action: &str) -> Self {
        Self::new(
            inventory(
                Some("DJI Osmo360"),
                vec![stream(5, "camd"), stream(3, "camd")],
            ),
            inventory(Some("INNER DIAGNOSTIC"), vec![stream(0, "djmd")]),
            vec![json!({"packets":[packet(0,&[0x0a,0])]})],
            action,
        )
    }
    fn inspect(&self, probe: &ProbeLimits) -> Result<NestedMetadata, NestedError> {
        inspect_nested(&self.input, &self.tool, probe, &self.transport.limits())
    }
    fn reaped(&self) {
        for pid in fs::read_to_string(self.temp.0.join("pids"))
            .unwrap()
            .lines()
        {
            assert!(
                !Path::new("/proc").join(pid).exists(),
                "owned child {pid} not reaped"
            );
        }
    }
}

#[test]
fn outer_encoder_is_authoritative_and_failed_neighbors_retain_exact_wire_and_timing() {
    for encoder in [
        None,
        Some("unknown camera"),
        Some("DJI Mini4 Pro"),
        Some("DJI Osmo360"),
    ] {
        let m = Mock::new(
            inventory(encoder, vec![stream(3, "camd")]),
            inventory(Some("Osmo 360 II"), vec![stream(0, "djmd")]),
            vec![
                json!({"packets":[packet(0,&[0x0a,0]),packet(0,&[0x0a,0x80]),packet(0,&[0x0a,0])]}),
            ],
            "",
        );
        let report = m.inspect(&ProbeLimits::default()).unwrap();
        let packets = &report.tracks[0].packets;
        for (i, p) in packets.iter().enumerate() {
            assert_eq!(
                p.outcome.original_packet(),
                if i == 1 { &[0x0a, 0x80] } else { &[0x0a, 0] }
            );
            assert_eq!(
                (p.pts, p.dts, p.source_position),
                (Some(-1), Some(144115188075868217), Some(u64::MAX))
            );
            match encoder {
                None => assert!(matches!(p.outcome, PacketOutcome::MissingEncoder(_))),
                Some("unknown camera") => assert!(
                    matches!(&p.outcome,PacketOutcome::DecodeFailed(e) if matches!(e.kind(),PacketFailureKind::UnknownEncoder(_)))
                ),
                Some("DJI Mini4 Pro") => assert!(
                    matches!(&p.outcome,PacketOutcome::DecodeFailed(e) if matches!(e.kind(),PacketFailureKind::UnsupportedSchema(_)))
                ),
                Some(_) if i == 1 => assert!(
                    matches!(&p.outcome,PacketOutcome::DecodeFailed(e) if matches!(e.kind(),PacketFailureKind::InvalidProtobuf(_)))
                ),
                Some(_) => assert!(
                    matches!(&p.outcome,PacketOutcome::Decoded(d) if d.registration().package=="oqb101")
                ),
            }
        }
        m.transport.empty();
        m.reaped();
    }
}

#[test]
fn first_numeric_camd_and_first_two_inner_indexes_excess_zero_packets_and_nonrecursive_absence() {
    let m = Mock::new(
        inventory(
            Some("DJI Osmo360"),
            vec![stream(5, "camd"), stream(3, "camd")],
        ),
        inventory(
            None,
            vec![stream(2, "xtmd"), stream(0, "djmd"), stream(1, "djmd")],
        ),
        vec![
            json!({"packets":[]}),
            json!({"packets":[packet(1,&[0x0a,0])]}),
        ],
        "",
    );
    let r = m.inspect(&ProbeLimits::default()).unwrap();
    assert_eq!(r.outer.selected_camd_index, Some(3));
    assert_eq!(r.outer.ignored_camd_indexes, [5]);
    assert_eq!(r.inner.as_ref().unwrap().selected_track_indexes, [0, 1]);
    assert_eq!(r.inner.as_ref().unwrap().excess_track_indexes, [2]);
    assert!(r.tracks[0].packets.is_empty());
    assert!(matches!(
        r.tracks[1].packets[0].outcome,
        PacketOutcome::Decoded(_)
    ));
    m.reaped();
    m.transport.empty();
    let m = Mock::new(
        inventory(None, vec![]),
        inventory(None, vec![stream(0, "camd")]),
        vec![],
        "",
    );
    let r = m.inspect(&ProbeLimits::default()).unwrap();
    assert_eq!(r.disposition, NestedDisposition::NoInnerDirectTracks);
    assert!(r.carrier.is_some());
    assert!(r.tracks.is_empty());
    m.reaped();
    m.transport.empty();
    fs::write(&m.input, box_bytes(b"free", b"no nested carrier")).unwrap();
    let r = m.inspect(&ProbeLimits::default()).unwrap();
    assert_eq!(r.disposition, NestedDisposition::NoNestedCarrier);
    assert!(r.carrier.is_none());
    let cli = bounded_cli(
        &Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("tests/fixtures/demux/absent-metadata-video-only.mp4"),
    );
    assert!(cli.status.success());
    assert!(String::from_utf8_lossy(&cli.stdout).contains("No selected camd"));
}

#[test]
fn malformed_headers_checked_spans_counts_and_carrier_caps_are_explicit() {
    let m = Mock::new(inventory(None, vec![]), inventory(None, vec![]), vec![], "");
    let mut cases = vec![
        vec![0; 7],
        [4_u32.to_be_bytes().as_slice(), b"META"].concat(),
        [1_u32.to_be_bytes().as_slice(), b"META", &[0; 7]].concat(),
        [
            1_u32.to_be_bytes().as_slice(),
            b"META",
            &15_u64.to_be_bytes(),
        ]
        .concat(),
        [50_u32.to_be_bytes().as_slice(), b"META", b"short"].concat(),
    ];
    cases.push(
        [
            box_bytes(b"free", b""),
            1_u32.to_be_bytes().to_vec(),
            b"META".to_vec(),
            u64::MAX.to_be_bytes().to_vec(),
        ]
        .concat(),
    );
    for raw in cases {
        fs::write(&m.input, raw).unwrap();
        let e = m.inspect(&ProbeLimits::default()).unwrap_err();
        assert_eq!(e.stage, NestedStage::BoxExtraction);
        assert!(matches!(e.kind, NestedErrorKind::MalformedBox(_)));
        assert!(e.context.carrier.is_none());
    }
    fs::write(&m.input, box_bytes(b"META", b"independent mock carrier")).unwrap();
    let mut nested = m.transport.limits();
    nested.carrier_bytes = 3;
    let e = inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested).unwrap_err();
    assert!(matches!(
        e.kind,
        NestedErrorKind::Limit {
            name: "carrier bytes",
            ..
        }
    ));
    nested = m.transport.limits();
    nested.top_level_boxes = 0;
    assert!(matches!(
        inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested)
            .unwrap_err()
            .kind,
        NestedErrorKind::Limit {
            name: "top-level boxes",
            ..
        }
    ));
    m.reaped();
    m.transport.empty();
    let m = Mock::standard("");
    for (count, bytes) in [(0, 100), (100, 2)] {
        let mut limits = m.transport.limits();
        limits.outer_camd_packets = count;
        limits.carrier_bytes = bytes;
        let e = inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &limits).unwrap_err();
        assert_eq!(e.stage, NestedStage::OuterPackets(3));
        assert!(
            matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::Limit{..}))
        );
        assert!(e.context.carrier.is_none());
    }
    m.reaped();
    m.transport.empty();
}

#[test]
fn inner_transport_errors_keep_complete_carrier_inventory_and_prior_tracks() {
    let mut malformed = packet(1, &[0x0a, 0]);
    malformed["data"] = json!("!!!!");
    let m = Mock::new(
        inventory(Some("DJI Osmo360"), vec![stream(3, "camd")]),
        inventory(None, vec![stream(0, "djmd"), stream(1, "xtmd")]),
        vec![
            json!({"packets":[packet(0,&[0x0a,0])]}),
            json!({"packets":[malformed]}),
        ],
        "",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert_eq!(e.stage, NestedStage::InnerPackets(1));
    assert!(
        matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::InvalidData(_)))
    );
    assert_eq!(
        e.context.carrier.unwrap().bytes(),
        b"independent mock carrier"
    );
    assert!(e.context.inner.is_some());
    assert_eq!(e.context.completed_tracks.len(), 1);
    assert_eq!(
        e.context.completed_tracks[0].packets[0]
            .outcome
            .original_packet(),
        [0x0a, 0]
    );
    m.reaped();
    m.transport.empty();
    for (field, value) in [
        ("stream_index", json!(1)),
        ("pts", json!(1.5)),
        ("dts", json!("9223372036854775808")),
        ("pos", json!(-2)),
        ("size", json!(1)),
        ("data", json!("CgA=\u{a0}")),
    ] {
        let mut bad = packet(0, &[0x0a, 0]);
        bad[field] = value;
        let m = Mock::new(
            inventory(None, vec![stream(3, "camd")]),
            inventory(None, vec![stream(0, "djmd")]),
            vec![json!({"packets":[bad]})],
            "",
        );
        let e = m.inspect(&ProbeLimits::default()).unwrap_err();
        assert!(e.context.carrier.is_some());
        assert!(
            matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::InvalidData(_)))
        );
        m.reaped();
        m.transport.empty();
    }
    let m = Mock::standard("");
    fs::write(m.temp.0.join("inner"), b"{broken").unwrap();
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(e.context.carrier.is_some());
    assert!(
        matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::InvalidJson(_)) && p.stdout_prefix()==b"{broken")
    );
    m.reaped();
    m.transport.empty();
}

#[test]
fn inner_aggregate_limits_and_outer_fragment_whitespace_and_optional_times() {
    let m = Mock::new(
        inventory(Some("DJI Osmo360"), vec![stream(3, "camd")]),
        inventory(None, vec![stream(0, "djmd"), stream(1, "xtmd")]),
        vec![
            json!({"packets":[packet(0,&[0x0a,0])]}),
            json!({"packets":[packet(1,&[0x0a,0])]}),
        ],
        "",
    );
    let limits = ProbeLimits {
        total_packet_bytes: 3,
        ..ProbeLimits::default()
    };
    // Outer carrier has its own bound and is also subject to the supplied probe aggregate.
    let e = m.inspect(&limits).unwrap_err();
    assert_eq!(e.stage, NestedStage::OuterPackets(3));
    fs::write(
        m.temp.0.join("outer"),
        serde_json::to_vec(&inventory(Some("DJI Osmo360"), vec![])).unwrap(),
    )
    .unwrap();
    let e = m.inspect(&limits).unwrap_err();
    assert_eq!(e.stage, NestedStage::InnerPackets(1));
    assert_eq!(e.context.completed_tracks.len(), 1);
    assert!(e.context.carrier.is_some());
    m.reaped();
    m.transport.empty();
    let m = Mock::standard("");
    let mut part = packet(3, b"independent mock carrier");
    part["data"] = json!(format!("\n \t{}\r\n", part["data"].as_str().unwrap()));
    part.as_object_mut().unwrap().remove("pts");
    part["dts"] = Value::Null;
    part["pos"] = json!("N/A");
    fs::write(
        m.temp.0.join("outer-packets"),
        serde_json::to_vec(&json!({"packets":[part]})).unwrap(),
    )
    .unwrap();
    let r = m.inspect(&ProbeLimits::default()).unwrap();
    let CarrierOrigin::CamdStreamParts { parts, .. } = r.carrier.as_ref().unwrap().origin() else {
        panic!()
    };
    assert_eq!(
        (parts[0].pts, parts[0].dts, parts[0].outer_source_position),
        (None, None, None)
    );
    m.reaped();
    m.transport.empty();
}

#[test]
fn temporary_permissions_cleanup_residue_and_primary_plus_cleanup_are_visible() {
    let m = Mock::standard(
        "if is_inner and not is_packet: (p.parent/'unknown').write_bytes(b'preserve')",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(matches!(e.kind, NestedErrorKind::CleanupOnly));
    assert_eq!(e.cleanup.unwrap().kind, CleanupKind::Residue);
    assert_eq!(e.context.completed_tracks.len(), 1);
    assert!(e.context.carrier.is_some());
    let directory = fs::read_dir(&m.transport.0)
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    assert_eq!(fs::read(directory.join("unknown")).unwrap(), b"preserve");
    assert!(!directory.join("carrier.bin").exists());
    m.reaped();
    let m = Mock::standard(
        "if is_inner:\n    (p.parent/'unknown').write_bytes(b'preserve')\n    sys.stderr.write('primary probe failure')\n    sys.exit(7)",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(
        matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::Exit(_)) && p.stderr_prefix()==b"primary probe failure")
    );
    assert_eq!(e.cleanup.unwrap().kind, CleanupKind::Residue);
    assert!(e.context.carrier.is_some());
    m.reaped();
    let m = Mock::standard(
        "if is_inner and not is_packet:\n    p.rename(p.parent/'held-original')\n    p.write_bytes(b'replaced')",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(
        matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::SourceChanged))
    );
    assert_eq!(e.cleanup.unwrap().kind, CleanupKind::Identity);
    let directory = fs::read_dir(&m.transport.0)
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    assert_eq!(
        fs::read(directory.join("carrier.bin")).unwrap(),
        b"replaced"
    );
    assert!(directory.join("held-original").exists());
    m.reaped();
    let m = Mock::standard("");
    let mut nested = m.transport.limits();
    nested.temp_root = m.transport.0.join("missing-parent");
    let e = inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested).unwrap_err();
    assert!(matches!(e.kind, NestedErrorKind::TemporaryIo(_)));
    assert!(e.context.carrier.is_some());
    assert!(e.cleanup.is_none());
    m.reaped();
    m.transport.empty();
}

#[test]
fn pipe_bounds_per_probe_and_total_deadlines_reap_owned_child_and_keep_stage_context() {
    for (action, pipe) in [
        (
            "sys.stdout.buffer.write(b'x'*10000);sys.stdout.flush();time.sleep(1)",
            "stdout",
        ),
        (
            "sys.stderr.buffer.write(b'x'*10000);sys.stderr.flush();time.sleep(1)",
            "stderr",
        ),
    ] {
        let m = Mock::standard(action);
        let limits = ProbeLimits {
            stdout_bytes: 128,
            stderr_bytes: 128,
            ..ProbeLimits::default()
        };
        let e = m.inspect(&limits).unwrap_err();
        assert!(
            matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::OutputLimit{pipe:actual,..} if actual==pipe))
        );
        m.reaped();
        m.transport.empty();
    }
    let m = Mock::standard("if is_inner: time.sleep(1)");
    let probe = ProbeLimits {
        timeout: Duration::from_millis(200),
        ..ProbeLimits::default()
    };
    let e = m.inspect(&probe).unwrap_err();
    assert!(
        matches!(e.kind,NestedErrorKind::Probe(ref p) if matches!(p.kind,DemuxErrorKind::Timeout))
    );
    assert_eq!(e.stage, NestedStage::InnerInventory);
    assert!(e.context.carrier.is_some());
    m.reaped();
    m.transport.empty();
    let m = Mock::standard("time.sleep(0.2)");
    let mut nested = m.transport.limits();
    nested.inspection_timeout = Duration::from_millis(300);
    let started = Instant::now();
    let e = inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested).unwrap_err();
    assert!(matches!(e.kind, NestedErrorKind::Deadline(_)));
    assert!(started.elapsed() < Duration::from_secs(2));
    m.reaped();
    m.transport.empty();
    nested.inspection_timeout = Duration::ZERO;
    assert!(matches!(
        inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested)
            .unwrap_err()
            .kind,
        NestedErrorKind::Deadline(None)
    ));
    nested.inspection_timeout = Duration::MAX;
    assert!(matches!(
        inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested)
            .unwrap_err()
            .kind,
        NestedErrorKind::InvalidPolicy(_)
    ));
}

#[test]
fn outer_source_change_nonregular_input_and_os_native_cli_paths() {
    let m = Mock::standard(
        "if is_inner: (root/next(x.name for x in root.iterdir() if x.name.startswith('-file:'))).write_bytes(b'changed')",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(matches!(e.kind, NestedErrorKind::SourceChanged(_)));
    assert!(e.context.carrier.is_some());
    m.reaped();
    m.transport.empty();
    let temp = Temp::new();
    let path = temp
        .0
        .join(OsString::from_vec(b"-file:camera-\xfe.mp4".to_vec()));
    fs::copy(fixture("camd-stream-default.mp4"), &path).unwrap();
    let r = inspect_nested(
        &path,
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
        &NestedLimits::default(),
    )
    .unwrap();
    assert_eq!(r.outer.requested_path, path);
    assert_eq!(r.outer.canonical_path, fs::canonicalize(&path).unwrap());
    assert!(bounded_cli(&path).status.success());
    let fifo = temp.0.join("no-writer.fifo");
    let c = CString::new(fifo.as_os_str().as_bytes()).unwrap();
    // SAFETY: live owned NUL-terminated pathname; this test owns the FIFO.
    assert_eq!(unsafe { libc::mkfifo(c.as_ptr(), 0o600) }, 0);
    let cli = bounded_cli(&fifo);
    assert!(!cli.status.success());
    assert!(String::from_utf8_lossy(&cli.stderr).contains("regular file"));
}

#[test]
fn replaced_directory_missing_file_and_post_carrier_pipe_or_deadline_failures_retain_context() {
    let m = Mock::standard(
        "if is_inner:\n    original=p.parent\n    original.rename(original.with_name(original.name+'-moved'))\n    original.mkdir(mode=0o700)\n    p.write_bytes(b'replacement')",
    );
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(
        matches!(e.kind, NestedErrorKind::Probe(ref p) if matches!(p.kind, DemuxErrorKind::SourceChanged))
    );
    assert_eq!(e.cleanup.unwrap().kind, CleanupKind::Identity);
    assert!(e.context.carrier.is_some());
    assert_eq!(fs::read_dir(&m.transport.0).unwrap().count(), 2);
    for entry in fs::read_dir(&m.transport.0).unwrap() {
        let p = entry.unwrap().path().join("carrier.bin");
        assert!(p.exists()); // Both uncertain directories are preserved.
    }
    m.reaped();
    let m = Mock::standard("if is_inner: p.unlink()");
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(e.context.carrier.is_some());
    assert_eq!(e.cleanup.unwrap().kind, CleanupKind::Inspect);
    assert_eq!(fs::read_dir(&m.transport.0).unwrap().count(), 1);
    m.reaped();
    for (action, pipe) in [
        (
            "if is_inner: sys.stdout.buffer.write(b'x'*10000);sys.stdout.flush();time.sleep(1)",
            "stdout",
        ),
        (
            "if is_inner: sys.stderr.buffer.write(b'x'*10000);sys.stderr.flush();time.sleep(1)",
            "stderr",
        ),
    ] {
        let m = Mock::standard(action);
        let limits = ProbeLimits {
            stdout_bytes: 4096,
            stderr_bytes: 128,
            ..ProbeLimits::default()
        };
        let e = m.inspect(&limits).unwrap_err();
        assert_eq!(e.stage, NestedStage::InnerInventory);
        assert!(e.context.carrier.is_some());
        assert!(
            matches!(e.kind, NestedErrorKind::Probe(ref p) if matches!(p.kind, DemuxErrorKind::OutputLimit { pipe: actual, .. } if actual == pipe))
        );
        m.reaped();
        m.transport.empty();
    }
    let m = Mock::standard("if is_inner: time.sleep(1)");
    let nested = NestedLimits {
        inspection_timeout: Duration::from_millis(600),
        ..m.transport.limits()
    };
    let e = inspect_nested(&m.input, &m.tool, &ProbeLimits::default(), &nested).unwrap_err();
    assert_eq!(e.stage, NestedStage::InnerInventory);
    assert!(matches!(e.kind, NestedErrorKind::Deadline(Some(_))));
    assert!(e.context.carrier.is_some());
    m.reaped();
    m.transport.empty();
}

#[test]
fn actual_unknown_outer_encoder_cli_exits_failure_after_preserving_all_statuses() {
    let temp = Temp::new();
    let path = temp.0.join("unknown-encoder.mp4");
    let raw = fs::read(fixture("camd-stream-default.mp4")).unwrap();
    let mut patched = raw.clone();
    let needle = b"DJI Osmo360";
    let mut replacements = 0;
    for (offset, bytes) in raw.windows(needle.len()).enumerate() {
        if bytes == needle {
            patched[offset..offset + needle.len()].copy_from_slice(b"UNKNOWN CAM");
            replacements += 1;
        }
    }
    assert_eq!(replacements, 2); // Inner and outer tags; no lengths/offsets change.
    fs::write(&path, patched).unwrap();
    let report = inspect_nested(
        &path,
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
        &NestedLimits::default(),
    )
    .unwrap();
    assert_eq!(report.outer.encoder.as_deref(), Some("UNKNOWN CAM"));
    assert!(
        matches!(&report.tracks[0].packets[0].outcome, PacketOutcome::DecodeFailed(e) if matches!(e.kind(), PacketFailureKind::UnknownEncoder(_)))
    );
    let cli = bounded_cli(&path);
    assert!(!cli.status.success());
    let text = String::from_utf8_lossy(&cli.stdout);
    assert!(text.contains("carrier_bytes="));
    assert!(text.contains("inner_packet=0"));
    assert!(text.contains("unknown encoder"));
}
