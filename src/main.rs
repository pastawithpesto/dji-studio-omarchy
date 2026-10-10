use std::{
    env,
    ffi::OsStr,
    path::Path,
    process::{Command, ExitCode},
};

fn text_argument<'a>(value: &'a OsStr, kind: &str) -> Result<&'a str, String> {
    value
        .to_str()
        .ok_or_else(|| format!("{kind} must be valid UTF-8"))
}

fn run() -> Result<(), String> {
    // Linux paths need not be UTF-8. Decode only the CLI's textual arguments.
    let a: Vec<_> = env::args_os().skip(1).collect();
    let option = a
        .first()
        .filter(|v| v.as_encoded_bytes().starts_with(b"--"))
        .map(|v| text_argument(v, "Option"))
        .transpose()?;
    if option == Some("--encoder") {
        if a.len() != 2 {
            return Err("Usage: dji-reframe --encoder ENCODER_TAG".into());
        }
        let encoder = text_argument(&a[1], "Encoder tag")?;
        let entry = dji_reframe::metadata::registration(encoder)
            .ok_or("Unknown encoder; retain raw metadata rather than guessing a schema")?;
        println!(
            "product={} protobuf_package={} (registry lookup; use --metadata for direct-track inspection)",
            entry.product, entry.package
        );
        return Ok(());
    }
    if option == Some("--metadata") {
        if a.len() != 2 {
            return Err("Usage: dji-reframe --metadata INPUT".into());
        }
        use dji_reframe::metadata::demux::{
            self, DirectDisposition, Ffprobe, PacketOutcome, ProbeLimits,
        };
        let report = demux::inspect_direct(
            Path::new(&a[1]),
            &Ffprobe::new("/usr/bin/ffprobe"),
            &ProbeLimits::default(),
        )
        .map_err(|e| e.to_string())?;
        println!(
            "encoder={:?} streams={} direct_tracks={} excess_indexes={:?}",
            report.encoder,
            report.streams.len(),
            report.tracks.len(),
            report.excess_track_indexes
        );
        match report.disposition {
            DirectDisposition::NoDirectTracks => {
                println!("No direct djmd/xtmd tracks; nested META payloads were not inspected.");
                return Ok(());
            }
            DirectDisposition::NestedUnsupported => {
                return Err("Nested camd metadata demux is unsupported".into());
            }
            DirectDisposition::DirectTracks => {}
        }
        let mut failed = 0;
        for track in report.tracks {
            let stream = track.stream;
            println!(
                "stream={} id={:?} tag={:?} time_base={}/{}",
                stream.index,
                stream.id,
                stream.codec_tag_string,
                stream.time_base.numerator,
                stream.time_base.denominator
            );
            for (i, packet) in track.packets.iter().enumerate() {
                let status = match &packet.outcome {
                    PacketOutcome::Decoded(decoded) => {
                        format!("decoded {}", decoded.registration().package)
                    }
                    PacketOutcome::DecodeFailed(error) => {
                        failed += 1;
                        error.to_string()
                    }
                    PacketOutcome::MissingEncoder(_) => {
                        failed += 1;
                        "missing format encoder".into()
                    }
                };
                println!(
                    "packet={i} pts={:?} dts={:?} position={:?} bytes={} status={status:?}",
                    packet.pts,
                    packet.dts,
                    packet.source_position,
                    packet.outcome.original_packet().len()
                );
            }
        }
        return if failed == 0 {
            Ok(())
        } else {
            Err(format!(
                "{failed} metadata packets could not be decoded; raw bytes retained by library API"
            ))
        };
    }
    if option == Some("--inspect") {
        if a.len() != 2 {
            return Err("Usage: dji-reframe --inspect MP4".into());
        }
        let mut input = std::fs::File::open(&a[1]).map_err(|e| e.to_string())?;
        let boxes =
            dji_reframe::metadata::nested_containers(&mut input).map_err(|e| e.to_string())?;
        if boxes.is_empty() {
            println!(
                "No top-level nested metadata container. Use --metadata for direct djmd/xtmd track inspection."
            );
        }
        for item in boxes {
            println!(
                "{} offset={} bytes={}",
                String::from_utf8_lossy(&item.tag),
                item.payload_offset,
                item.payload_len
            );
        }
        return Ok(());
    }
    if option == Some("--help") {
        println!(
            "dji-reframe INPUT OUTPUT [YAW PITCH HFOV]\ndji-reframe --encoder ENCODER_TAG\ndji-reframe --inspect MP4\ndji-reframe --metadata INPUT\n--metadata inspects up to two direct djmd/xtmd tracks with FFprobe base64 support.\nNested metadata demux and camera/Windows compatibility are unverified.\n--inspect scans top-level nested box extents only.\nReframe an already stitched equirectangular video into 1920x1080 H.264.\nDefaults: yaw=0 pitch=0 horizontal FOV=90. Existing output is never overwritten.\nRequires FFmpeg with v360 and libx264. Raw DJI dual-lens footage is not supported yet."
        );
        return Ok(());
    }
    if a.len() != 2 && a.len() != 5 {
        return Err("Usage: dji-reframe INPUT OUTPUT [YAW PITCH HFOV]".into());
    }
    if !Path::new(&a[0]).is_file() {
        return Err("Input must be an existing file".into());
    }
    if Path::new(&a[1]).exists() {
        return Err("Output already exists".into());
    }
    let mut view = [0.0_f64, 0.0, 90.0];
    if a.len() == 5 {
        for (i, v) in a[2..].iter().enumerate() {
            let v = text_argument(v, "Angle")?;
            view[i] = v.parse().map_err(|_| format!("Invalid angle: {v}"))?;
        }
    }
    for (value, low, high) in [
        (view[0], -180.0, 180.0),
        (view[1], -90.0, 90.0),
        (view[2], 1.0, 179.0),
    ] {
        if !value.is_finite() || !(low..=high).contains(&value) {
            return Err(format!("Angle must be finite and between {low} and {high}"));
        }
    }
    // These projection/export defaults are independent prototype choices,
    // not recovered DJI settings. See README.md for the evidence boundary.
    let vertical_fov =
        (2.0 * ((view[2].to_radians() / 2.0).tan() * 1080.0 / 1920.0).atan()).to_degrees();
    let filter = format!(
        "v360=input=equirect:output=flat:w=1920:h=1080:yaw={}:pitch={}:h_fov={}:v_fov={vertical_fov}",
        view[0], view[1], view[2]
    );
    let status = Command::new("ffmpeg")
        .args(["-nostdin", "-n", "-i"])
        .arg(&a[0])
        .args([
            "-map",
            "0:v:0",
            "-map",
            "0:a?",
            "-vf",
            &filter,
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-movflags",
            "+faststart",
        ])
        .arg(&a[1])
        .status()
        .map_err(|e| format!("Could not start FFmpeg: {e}"))?;
    if !status.success() {
        return Err(format!("FFmpeg failed: {status}"));
    }
    Ok(())
}
fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{e}");
            ExitCode::FAILURE
        }
    }
}
