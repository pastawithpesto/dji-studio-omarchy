//! Real independent synthetic carrier oracles plus native-policy process mocks.
//! No camera/Windows parity or dual-schema semantics in mixed carriers.
use base64::{Engine, engine::general_purpose::STANDARD};
use dji_reframe::metadata::{
    demux::{
        DemuxError, DemuxErrorKind, DirectDisposition, DirectMetadata, Ffprobe, PacketOutcome,
        ProbeLimits, ProbeStage, TimeBase, inspect_direct,
    },
    packet::PacketFailureKind,
};
use prost_reflect::{ReflectMessage, Value as ProtoValue};
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
        .join("tests/fixtures/demux")
        .join(name)
}
fn protobuf(package: &str) -> Vec<u8> {
    fs::read(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join(format!("tests/fixtures/metadata/{package}-complete.pb")),
    )
    .unwrap()
}
fn real(name: &str) -> DirectMetadata {
    inspect_direct(
        &fixture(name),
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
    )
    .unwrap_or_else(|e| panic!("{name}: {e}"))
}
static NEXT: AtomicU64 = AtomicU64::new(0);
struct Temp(PathBuf);
impl Temp {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "dji-sol1-demux-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }
}
impl Drop for Temp {
    fn drop(&mut self) {
        // Only this test's exclusively created directory is removed.
        fs::remove_dir_all(&self.0).unwrap();
    }
}
fn bounded_cli(path: &Path) -> Output {
    let mut child = Command::new(env!("CARGO_BIN_EXE_dji-reframe"))
        .arg("--metadata")
        .arg(path)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let start = Instant::now();
    loop {
        if child.try_wait().unwrap().is_some() {
            return child.wait_with_output().unwrap();
        }
        if start.elapsed() > Duration::from_secs(5) {
            let _ = child.kill();
            let _ = child.wait();
            panic!("owned CLI child exceeded test deadline");
        }
        thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn real_matching_carriers_decode_full_packets_with_stream_context() {
    for (file, encoder, package, tag) in [
        ("one-djmd-oqb101.mp4", "DJI Osmo360", "oqb101", "djmd"),
        ("one-xtmd-wab530.mp4", "Osmo 360 II", "wab530", "xtmd"),
    ] {
        let report = real(file);
        assert_eq!(report.encoder.as_deref(), Some(encoder));
        assert_eq!(report.disposition, DirectDisposition::DirectTracks);
        assert_eq!(report.tracks.len(), 1);
        let track = &report.tracks[0];
        assert_eq!(track.stream.index, 0);
        assert_eq!(track.stream.id.as_deref(), Some("0x1"));
        assert_eq!(track.stream.codec_tag_string, tag);
        assert_eq!(
            track.stream.time_base,
            TimeBase {
                numerator: 1,
                denominator: 1000
            }
        );
        assert_eq!(track.packets.len(), 1);
        let packet = &track.packets[0];
        assert_eq!(
            (packet.pts, packet.dts, packet.source_position),
            (Some(0), Some(0), Some(749))
        );
        assert_eq!(packet.outcome.original_packet(), protobuf(package));
        let PacketOutcome::Decoded(decoded) = &packet.outcome else {
            panic!("matching schema failed")
        };
        assert_eq!(decoded.registration().package, package);
        assert_eq!(
            decoded.message().descriptor().full_name(),
            format!("{package}.ProductMeta")
        );
        // Independent descriptor fixture known value; no unit/axis conversion.
        let ProtoValue::Message(clip) = decoded
            .message()
            .get_field_by_name("clip_meta")
            .unwrap()
            .into_owned()
        else {
            panic!()
        };
        let ProtoValue::Message(header) = clip
            .get_field_by_name("clip_meta_header")
            .unwrap()
            .into_owned()
        else {
            panic!()
        };
        assert_eq!(
            header.get_field_by_name("clip_timestamp").unwrap().as_ref(),
            &ProtoValue::U64(18446744073709551613)
        );
        assert_eq!(header.unknown_fields().next().unwrap().number(), 99);
    }
}

#[test]
fn real_mixed_carriers_select_first_two_preserve_bytes_and_global_dispatch() {
    for (file, indexes, excess, denominators) in [
        ("mixed-djmd-video-xtmd.mp4", [0, 2], vec![], [1000, 1000]),
        (
            "three-selected-with-video-gap.mp4",
            [0, 2],
            vec![3],
            [1000, 1000],
        ),
        ("two-selected-djmd-xtmd.mp4", [0, 1], vec![], [1000, 90000]),
    ] {
        let report = real(file);
        assert_eq!(
            report
                .tracks
                .iter()
                .map(|t| t.stream.index)
                .collect::<Vec<_>>(),
            indexes
        );
        assert_eq!(report.excess_track_indexes, excess);
        for (i, package) in ["oqb101", "wab530"].into_iter().enumerate() {
            let track = &report.tracks[i];
            assert_eq!(track.stream.time_base.denominator, denominators[i]);
            assert_eq!(
                track.packets[0].outcome.original_packet(),
                protobuf(package)
            );
            // WAB bytes under OQB encoder are a transport mismatch oracle;
            // protobuf may accept unknown/differently placed fields. No schema
            // fallback and no assertion of WAB semantic compatibility.
            match &track.packets[0].outcome {
                PacketOutcome::Decoded(p) => assert_eq!(p.registration().package, "oqb101"),
                PacketOutcome::DecodeFailed(e) => {
                    assert!(matches!(e.kind(), PacketFailureKind::InvalidProtobuf(_)))
                }
                PacketOutcome::MissingEncoder(_) => panic!("global encoder missing"),
            }
        }
    }
}

#[test]
fn real_absence_nested_and_encoder_failures_remain_distinct() {
    let absent = real("absent-metadata-video-only.mp4");
    assert_eq!(absent.disposition, DirectDisposition::NoDirectTracks);
    assert_eq!(absent.streams.len(), 1);
    assert!(absent.tracks.is_empty());
    let nested = real("camd-only-designed.mp4");
    assert_eq!(nested.disposition, DirectDisposition::NestedUnsupported);
    assert!(nested.tracks.is_empty());
    for (file, encoder) in [
        ("unknown-encoder-djmd.mp4", "NOT DJI"),
        ("missing-encoder-djmd.mp4", ""),
    ] {
        let report = real(file);
        assert_eq!(report.encoder.as_deref(), Some(encoder));
        let PacketOutcome::DecodeFailed(e) = &report.tracks[0].packets[0].outcome else {
            panic!()
        };
        assert!(matches!(e.kind(), PacketFailureKind::UnknownEncoder(s) if s == encoder));
        assert_eq!(e.original_packet(), protobuf("oqb101"));
    }
    let missing = real("missing-encoder-no-item.mp4");
    assert_eq!(missing.encoder, None);
    assert!(
        matches!(&missing.tracks[0].packets[0].outcome, PacketOutcome::MissingEncoder(b) if b == &protobuf("oqb101"))
    );
}

#[test]
fn real_signed_and_large_packet_times_survive_without_float_rounding() {
    for (file, time) in [
        ("negative-pts-minus1.mp4", -1),
        ("large-edit-list-pts.mp4", 144115188075868217),
    ] {
        let report = real(file);
        let p = &report.tracks[0].packets[0];
        assert_eq!((p.pts, p.dts), (Some(time), Some(time)));
        assert_eq!(
            report.tracks[0].stream.time_base,
            TimeBase {
                numerator: 1,
                denominator: 1000
            }
        );
        assert_eq!(p.outcome.original_packet(), protobuf("oqb101"));
    }
}

#[test]
fn real_non_utf8_colon_dash_path_and_cli_diagnostics() {
    let temp = Temp::new();
    let path = temp
        .0
        .join(OsString::from_vec(b"-file:camera-\xfe.mp4".to_vec()));
    fs::copy(fixture("one-djmd-oqb101.mp4"), &path).unwrap();
    let report = inspect_direct(
        &path,
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
    )
    .unwrap();
    assert_eq!(report.requested_path, path);
    assert_eq!(report.canonical_path, fs::canonicalize(&path).unwrap());
    assert_eq!(
        report.tracks[0].packets[0].outcome.original_packet(),
        protobuf("oqb101")
    );
    let cli = bounded_cli(&path);
    assert!(
        cli.status.success(),
        "{}",
        String::from_utf8_lossy(&cli.stderr)
    );
    assert!(String::from_utf8(cli.stdout).unwrap().contains("oqb101"));
    for (file, success, phrase) in [
        ("absent-metadata-video-only.mp4", true, "No direct"),
        ("camd-only-designed.mp4", false, "Nested"),
        ("unknown-encoder-djmd.mp4", false, "unknown encoder"),
    ] {
        let cli = bounded_cli(&fixture(file));
        assert_eq!(cli.status.success(), success);
        let text = format!(
            "{}{}",
            String::from_utf8_lossy(&cli.stdout),
            String::from_utf8_lossy(&cli.stderr)
        );
        assert!(text.contains(phrase), "{text}");
    }
}

#[test]
fn truncated_container_is_probe_failure_and_fifo_is_bounded_input_rejection() {
    let temp = Temp::new();
    let truncated = temp.0.join("truncated.mp4");
    fs::write(
        &truncated,
        &fs::read(fixture("one-djmd-oqb101.mp4")).unwrap()[..100],
    )
    .unwrap();
    let e = inspect_direct(
        &truncated,
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
    )
    .unwrap_err();
    assert!(matches!(e.kind, DemuxErrorKind::Exit(_)));
    assert_eq!(e.stage, Some(ProbeStage::Inventory));
    assert!(String::from_utf8_lossy(e.stderr_prefix()).contains("moov atom not found"));
    let fifo = temp.0.join("no-writer.fifo");
    let name = CString::new(fifo.as_os_str().as_bytes()).unwrap();
    // SAFETY: owned NUL-terminated path and valid mode; mkfifo accesses no Rust
    // memory other than that live pathname. This test owns the created FIFO.
    assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0);
    let cli = bounded_cli(&fifo);
    assert!(!cli.status.success());
    assert!(String::from_utf8_lossy(&cli.stderr).contains("regular file"));
}

fn inventory_value() -> Value {
    json!({"format":{"tags":{"encoder":"DJI Osmo360"}},"streams":[{"index":0,"id":"0x1","codec_tag":"0x646d6a64","codec_tag_string":"djmd","time_base":"1/1000"}]})
}
fn packet(bytes: &[u8]) -> Value {
    json!({"stream_index":0,"pts":-1,"dts":"144115188075868217","pos":"-1","size":bytes.len().to_string(),"data":STANDARD.encode(bytes)})
}
struct Mock {
    temp: Temp,
    input: PathBuf,
    tool: Ffprobe,
}
impl Mock {
    fn new(inventory: Value, packets: Value, prefix: &str) -> Self {
        Self::raw(
            serde_json::to_vec(&inventory).unwrap(),
            serde_json::to_vec(&packets).unwrap(),
            prefix,
        )
    }
    fn raw(inventory: Vec<u8>, packets: Vec<u8>, prefix: &str) -> Self {
        let temp = Temp::new();
        let input = temp
            .0
            .join(OsString::from_vec(b"-file:input-\xfe.mp4".to_vec()));
        fs::write(&input, b"owned mock regular source").unwrap();
        fs::write(temp.0.join("inventory"), inventory).unwrap();
        fs::write(temp.0.join("packets"), packets).unwrap();
        let script = temp.0.join("trusted probe.py");
        let source = format!(
            r#"#!/usr/bin/python3
import os,sys,time,json
from pathlib import Path
root=Path(__file__).resolve().parent
(root/'pid').write_text(str(os.getpid()))
args=sys.argv[1:]
base=['-v','error','-protocol_whitelist','file','-of','json=string_validation=fail']
tail=['-i',os.fsdecode(bytes.fromhex('{}'))]
if '-show_packets' in args:
    expected=base+['-select_streams','0','-show_packets','-show_data','-data_dump_format','base64','-show_entries','packet=stream_index,pts,dts,pos,size,data']+tail
    data=(root/'packets').read_bytes()
else:
    expected=base+['-show_entries','format_tags=encoder:stream=index,id,codec_tag,codec_tag_string,time_base']+tail
    data=(root/'inventory').read_bytes()
assert args==expected,repr(args)
assert sys.stdin.buffer.read()==b''
with (root/'argv').open('a') as f: f.write(json.dumps([os.fsencode(x).hex() for x in args])+'\n')
{}
sys.stdout.buffer.write(data)
"#,
            input
                .as_os_str()
                .as_bytes()
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect::<String>(),
            prefix
        );
        fs::write(&script, source).unwrap();
        fs::set_permissions(&script, fs::Permissions::from_mode(0o700)).unwrap();
        Self {
            temp,
            input,
            tool: Ffprobe::new(script),
        }
    }
    fn inspect(&self, limits: &ProbeLimits) -> Result<DirectMetadata, DemuxError> {
        inspect_direct(&self.input, &self.tool, limits)
    }
    fn assert_reaped(&self) {
        let pid = fs::read_to_string(self.temp.0.join("pid")).unwrap();
        assert!(
            !Path::new("/proc").join(pid).exists(),
            "owned child not reaped"
        );
    }
}
fn mock(packets: Vec<Value>) -> Mock {
    Mock::new(inventory_value(), json!({"packets":packets}), "")
}

#[test]
fn mock_exact_argv_optional_timing_and_malformed_protobuf_retains_context() {
    let mut absent = packet(&[0x0a, 0]);
    absent.as_object_mut().unwrap().remove("pts");
    absent["dts"] = Value::Null;
    absent["pos"] = json!("N/A");
    let mut na = packet(&[0x0a, 0]);
    na["pts"] = json!("N/A");
    na["pos"] = Value::Null;
    let mut malformed = packet(&[0x0a, 0x80]);
    malformed["pos"] = json!("18446744073709551615");
    let m = mock(vec![absent, na, malformed]);
    let report = m.inspect(&ProbeLimits::default()).unwrap();
    let p = &report.tracks[0].packets;
    assert_eq!(
        (p[0].pts, p[0].dts, p[0].source_position),
        (None, None, None)
    );
    assert_eq!((p[1].pts, p[1].dts), (None, Some(144115188075868217)));
    assert_eq!(
        (p[2].pts, p[2].dts, p[2].source_position),
        (Some(-1), Some(144115188075868217), Some(u64::MAX))
    );
    assert!(
        matches!(&p[2].outcome, PacketOutcome::DecodeFailed(e) if matches!(e.kind(), PacketFailureKind::InvalidProtobuf(_)))
    );
    assert_eq!(p[2].outcome.original_packet(), [0x0a, 0x80]);
    assert!(matches!(&p[0].outcome, PacketOutcome::Decoded(_)));
    assert!(matches!(&p[1].outcome, PacketOutcome::Decoded(_)));
    assert_eq!(
        fs::read_to_string(m.temp.0.join("argv"))
            .unwrap()
            .lines()
            .count(),
        2
    );
    m.assert_reaped();
}

#[test]
fn registered_unsupported_schema_does_not_guess_a_supported_decoder() {
    let mut inventory = inventory_value();
    inventory["format"]["tags"]["encoder"] = json!("DJI Mini4 Pro");
    let bytes = protobuf("oqb101");
    let m = Mock::new(inventory, json!({"packets":[packet(&bytes)]}), "");
    let report = m.inspect(&ProbeLimits::default()).unwrap();
    let p = &report.tracks[0].packets[0];
    let PacketOutcome::DecodeFailed(error) = &p.outcome else {
        panic!()
    };
    assert!(
        matches!(error.kind(),PacketFailureKind::UnsupportedSchema(r) if r.package == "wab140")
    );
    assert_eq!(p.outcome.original_packet(), bytes);
    assert_eq!((p.pts, p.dts), (Some(-1), Some(144115188075868217)));
}

#[test]
fn mock_invalid_json_inventory_and_stream_identity_are_explicit() {
    let m = Mock::raw(b"{broken".to_vec(), vec![], "");
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(matches!(e.kind, DemuxErrorKind::InvalidJson(_)));
    assert_eq!(e.stdout_prefix(), b"{broken");
    m.assert_reaped();
    let mut cases = vec![json!({"streams":[]}), json!({"format":{},"streams":{}})];
    for (field, value) in [
        ("index", json!(4294967296_u64)),
        ("index", json!(1.5)),
        ("id", json!(2)),
        ("time_base", json!("1/0")),
        ("time_base", json!("2147483648/1")),
        ("codec_tag", json!("0x100000000")),
        ("codec_tag_string", Value::Null),
    ] {
        let mut inventory = inventory_value();
        inventory["streams"][0][field] = value;
        cases.push(inventory);
    }
    let mut duplicate = inventory_value();
    let stream = duplicate["streams"][0].clone();
    duplicate["streams"].as_array_mut().unwrap().push(stream);
    cases.push(duplicate);
    let mut bad_encoder = inventory_value();
    bad_encoder["format"]["tags"]["encoder"] = Value::Null;
    cases.push(bad_encoder);
    for inventory in cases {
        let m = Mock::new(inventory, json!({"packets":[]}), "");
        assert!(matches!(
            m.inspect(&ProbeLimits::default()).unwrap_err().kind,
            DemuxErrorKind::InvalidData(_)
        ));
        m.assert_reaped();
    }
    let mut wrong = packet(&[]);
    wrong["stream_index"] = json!(1);
    let m = mock(vec![wrong]);
    let e = m.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(matches!(e.kind, DemuxErrorKind::InvalidData(_)));
    assert_eq!(e.stage, Some(ProbeStage::Packets(0)));
}

#[test]
fn mock_invalid_packet_numbers_base64_and_checked_arithmetic() {
    let mut cases = Vec::new();
    for (field, value) in [
        ("pts", json!(1.5)),
        ("pts", json!(9223372036854775808_u64)),
        ("dts", json!("-9223372036854775809")),
        ("dts", json!("1.0")),
        ("pos", json!(-2)),
        ("pos", json!("18446744073709551616")),
        ("size", json!(-1)),
        ("size", json!(2.5)),
        ("size", Value::Null),
        ("data", json!("!!!!")),
        ("data", json!("CgB=")),
        ("data", json!("Cg==")),
        ("data", json!("CgA=".to_owned() + "\u{a0}")),
    ] {
        let mut p = packet(&[0x0a, 0]);
        p[field] = value;
        cases.push(p);
    }
    for p in cases {
        let m = mock(vec![p]);
        assert!(matches!(
            m.inspect(&ProbeLimits::default()).unwrap_err().kind,
            DemuxErrorKind::InvalidData(_)
        ));
    }
    let mut whitespace = packet(&[0x0a, 0]);
    whitespace["data"] = json!("\n Cg\tA=\r \n");
    assert_eq!(
        mock(vec![whitespace])
            .inspect(&ProbeLimits::default())
            .unwrap()
            .tracks[0]
            .packets[0]
            .outcome
            .original_packet(),
        [0x0a, 0]
    );
    let mut huge = packet(&[]);
    huge["size"] = json!(usize::MAX.to_string());
    let limits = ProbeLimits {
        packet_bytes: usize::MAX,
        total_packet_bytes: usize::MAX,
        ..ProbeLimits::default()
    };
    let e = mock(vec![huge.clone()]).inspect(&limits).unwrap_err();
    assert!(matches!(e.kind,DemuxErrorKind::InvalidData(ref s) if s.contains("overflow")));
    let e = mock(vec![packet(&[0]), huge]).inspect(&limits).unwrap_err();
    assert!(
        matches!(e.kind,DemuxErrorKind::InvalidData(ref s) if s == "total packet size overflow")
    );
}

#[test]
fn mock_count_and_wire_limits_allow_boundary_and_reject_next_byte() {
    let m = mock(vec![packet(&[0x0a, 0]), packet(&[0x0a, 0])]);
    let mut limits = ProbeLimits {
        streams: 1,
        packets_per_track: 2,
        packet_bytes: 2,
        total_packet_bytes: 4,
        ..ProbeLimits::default()
    };
    assert_eq!(m.inspect(&limits).unwrap().tracks[0].packets.len(), 2);
    for (name, change) in [
        ("stream count", 0),
        ("packet count", 1),
        ("packet bytes", 2),
        ("total packet bytes", 3),
    ] {
        match change {
            0 => limits.streams = 0,
            1 => limits.packets_per_track = 1,
            2 => limits.packet_bytes = 1,
            3 => limits.total_packet_bytes = 3,
            _ => unreachable!(),
        }
        assert!(
            matches!(m.inspect(&limits).unwrap_err().kind,DemuxErrorKind::Limit {name:n,..} if n==name)
        );
        limits = ProbeLimits {
            streams: 1,
            packets_per_track: 2,
            packet_bytes: 2,
            total_packet_bytes: 4,
            ..ProbeLimits::default()
        };
    }
}

#[test]
fn mock_pipe_caps_failure_exit_timeout_and_source_change_reap_owned_child() {
    let empty = json!({"format":{},"streams":[]});
    let bytes = serde_json::to_vec(&empty).unwrap();
    let boundary = Mock::new(empty.clone(), json!({"packets":[]}), "os.write(2,b'e'*64)");
    let limits = ProbeLimits {
        stdout_bytes: bytes.len(),
        stderr_bytes: 64,
        ..ProbeLimits::default()
    };
    assert!(boundary.inspect(&limits).is_ok());
    boundary.assert_reaped();
    let too_small = ProbeLimits {
        stdout_bytes: bytes.len() - 1,
        ..limits.clone()
    };
    let e = boundary.inspect(&too_small).unwrap_err();
    assert!(matches!(
        e.kind,
        DemuxErrorKind::OutputLimit { pipe: "stdout", .. }
    ));
    assert_eq!(e.stdout_prefix().len(), bytes.len() - 1);
    boundary.assert_reaped();
    // Exceed the OS pipe capacity while remaining inside the caller cap; the
    // stderr producer must complete and then emit a valid stdout document.
    let heavy = Mock::new(
        empty.clone(),
        json!({"packets":[]}),
        "os.write(2,b'e'*131072)",
    );
    let heavy_limits = ProbeLimits {
        stderr_bytes: 131072,
        ..ProbeLimits::default()
    };
    assert!(heavy.inspect(&heavy_limits).is_ok());
    heavy.assert_reaped();
    // A continuously readable pipe must not postpone the elapsed-time check.
    let continuous = Mock::new(
        empty.clone(),
        json!({"packets":[]}),
        "while True:\n    os.write(1,b'x'*8192)\n    time.sleep(0.002)",
    );
    let continuous_limits = ProbeLimits {
        stdout_bytes: 16 * 1024 * 1024,
        timeout: Duration::from_millis(250),
        ..ProbeLimits::default()
    };
    assert!(matches!(
        continuous.inspect(&continuous_limits).unwrap_err().kind,
        DemuxErrorKind::Timeout
    ));
    continuous.assert_reaped();
    for (prefix, kind) in [
        ("os.write(2,b'e'*65); time.sleep(10)", "stderr"),
        ("os.write(1,b'x'*1000000); time.sleep(10)", "stdout"),
        ("os.write(2,b'failure'); raise SystemExit(7)", "exit"),
        ("time.sleep(10)", "timeout"),
        ("open(sys.argv[-1],'ab').write(b'changed')", "changed"),
    ] {
        let m = Mock::new(empty.clone(), json!({"packets":[]}), prefix);
        let limits = ProbeLimits {
            stdout_bytes: 64,
            stderr_bytes: 64,
            timeout: Duration::from_millis(250),
            ..ProbeLimits::default()
        };
        let start = Instant::now();
        let e = m.inspect(&limits).unwrap_err();
        assert!(start.elapsed() < Duration::from_secs(2));
        assert!(
            match kind {
                "stderr" => matches!(e.kind, DemuxErrorKind::OutputLimit { pipe: "stderr", .. }),
                "stdout" => matches!(e.kind, DemuxErrorKind::OutputLimit { pipe: "stdout", .. }),
                "exit" => matches!(e.kind, DemuxErrorKind::Exit(_)),
                "timeout" => matches!(e.kind, DemuxErrorKind::Timeout),
                "changed" => matches!(e.kind, DemuxErrorKind::SourceChanged),
                _ => false,
            },
            "{kind}: {e}"
        );
        assert!(e.stdout_prefix().len() <= 64);
        assert!(e.stderr_prefix().len() <= 64);
        m.assert_reaped();
    }
    let changed_packet = Mock::new(
        inventory_value(),
        json!({"packets":[packet(&[])]}),
        "if '-show_packets' in args: open(sys.argv[-1],'ab').write(b'changed')",
    );
    let error = changed_packet.inspect(&ProbeLimits::default()).unwrap_err();
    assert!(matches!(error.kind, DemuxErrorKind::SourceChanged));
    assert_eq!(error.stage, Some(ProbeStage::Packets(0)));
    changed_packet.assert_reaped();
    let temp = Temp::new();
    let input = temp.0.join("regular");
    fs::write(&input, b"data").unwrap();
    let e = inspect_direct(
        &input,
        &Ffprobe::new(temp.0.join("no executable")),
        &ProbeLimits::default(),
    )
    .unwrap_err();
    assert!(matches!(e.kind, DemuxErrorKind::Spawn(_)));
    let e = inspect_direct(
        &temp.0,
        &Ffprobe::new("/usr/bin/ffprobe"),
        &ProbeLimits::default(),
    )
    .unwrap_err();
    assert!(matches!(e.kind, DemuxErrorKind::Input(_)));
}
