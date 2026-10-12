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

fn frame_rate(value: &serde_json::Value) -> Option<(u64, u64)> {
    let (numerator, denominator) = value.as_str()?.split_once('/')?;
    let numerator = numerator.parse().ok()?;
    let denominator = denominator.parse().ok()?;
    if numerator == 0 || denominator == 0 {
        return None;
    }
    Some((numerator, denominator))
}

fn raw_camera_pair(input: &Path) -> Result<[u64; 2], String> {
    let probe = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "stream=index,codec_type,codec_name,width,height,avg_frame_rate:stream_disposition=attached_pic,timed_thumbnails",
            "-of",
            "json",
            "-i",
        ])
        .arg(input)
        .output()
        .map_err(|e| format!("Could not start FFprobe: {e}"))?;
    if !probe.status.success() {
        return Err(format!(
            "FFprobe failed: {}: {}",
            probe.status,
            String::from_utf8_lossy(&probe.stderr).trim()
        ));
    }
    let inventory: serde_json::Value = serde_json::from_slice(&probe.stdout)
        .map_err(|e| format!("Invalid FFprobe stream list: {e}"))?;
    let streams = inventory["streams"]
        .as_array()
        .ok_or("FFprobe did not return a stream list")?;
    let cameras: Vec<_> = streams
        .iter()
        .filter(|stream| {
            stream["codec_type"] == "video"
                && stream["codec_name"] != "mjpeg"
                && stream["disposition"]["attached_pic"].as_u64().unwrap_or(0) == 0
                && stream["disposition"]["timed_thumbnails"].as_u64().unwrap_or(0) == 0
        })
        .collect();
    let pair_error = "Raw panorama input must have exactly two matching square camera video streams";
    if cameras.len() != 2 {
        return Err(pair_error.into());
    }
    let first = cameras[0];
    let second = cameras[1];
    let width = first["width"].as_u64().ok_or(pair_error)?;
    let height = first["height"].as_u64().ok_or(pair_error)?;
    let codec = first["codec_name"].as_str().ok_or(pair_error)?;
    let left_rate = frame_rate(&first["avg_frame_rate"]).ok_or(pair_error)?;
    let right_rate = frame_rate(&second["avg_frame_rate"]).ok_or(pair_error)?;
    if width == 0
        || width != height
        || second["width"].as_u64() != Some(width)
        || second["height"].as_u64() != Some(height)
        || second["codec_name"].as_str() != Some(codec)
        || u128::from(left_rate.0) * u128::from(right_rate.1)
            != u128::from(right_rate.0) * u128::from(left_rate.1)
    {
        return Err(pair_error.into());
    }
    let indexes = [
        first["index"].as_u64().ok_or(pair_error)?,
        second["index"].as_u64().ok_or(pair_error)?,
    ];
    if indexes[0] == indexes[1] {
        return Err(pair_error.into());
    }
    Ok(indexes)
}

fn raw_panorama(input: &Path, output: &Path) -> Result<(), String> {
    if !input.is_file() {
        return Err("Input must be an existing file".into());
    }
    match output.symlink_metadata() {
        Ok(_) => return Err("Output already exists".into()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
        Err(e) => return Err(format!("Could not check output path: {e}")),
    }
    // Absolute paths prevent FFmpeg from reading a path as an option or URL.
    let input = if input.is_absolute() {
        input.to_path_buf()
    } else {
        env::current_dir().map_err(|e| e.to_string())?.join(input)
    };
    let output = if output.is_absolute() {
        output.to_path_buf()
    } else {
        env::current_dir().map_err(|e| e.to_string())?.join(output)
    };
    let [left, right] = raw_camera_pair(&input)?;
    let filter = format!(
        "[0:{left}][0:{right}]hstack=inputs=2:shortest=1,v360=input=dfisheye:output=equirect:w=2048:h=1024[panorama]"
    );
    eprintln!("Experimental raw panorama preview. DJI lens calibration and seam correction are not applied.");
    let status = Command::new("ffmpeg")
        .args(["-nostdin", "-n", "-i"])
        .arg(input)
        .args([
            "-filter_complex",
            &filter,
            "-map",
            "[panorama]",
            "-map",
            "0:a:0?",
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-pix_fmt",
            "yuv420p",
            "-fps_mode",
            "passthrough",
            "-c:a",
            "aac",
            "-movflags",
            "+faststart",
            "-f",
            "mp4",
        ])
        .arg(output)
        .status()
        .map_err(|e| format!("Could not start FFmpeg: {e}"))?;
    if !status.success() {
        return Err(format!("FFmpeg failed: {status}"));
    }
    Ok(())
}

fn print_nested(
    outer: Option<&dji_reframe::metadata::demux::OuterInventory>,
    carrier: Option<&dji_reframe::metadata::demux::NestedCarrier>,
    inner: Option<&dji_reframe::metadata::demux::InnerInventory>,
    tracks: &[dji_reframe::metadata::demux::MetadataTrack],
) -> usize {
    use dji_reframe::metadata::demux::{CarrierOrigin, PacketOutcome};
    if let Some(outer) = outer {
        println!(
            "outer_encoder={:?} selected_camd={:?} ignored_camd={:?}",
            outer.encoder, outer.selected_camd_index, outer.ignored_camd_indexes
        );
        for stream in &outer.streams {
            println!(
                "outer_stream={} id={:?} tag={:?} time_base={}/{}",
                stream.index,
                stream.id,
                stream.codec_tag_string,
                stream.time_base.numerator,
                stream.time_base.denominator
            );
        }
    }
    if let Some(carrier) = carrier {
        println!(
            "carrier_bytes={} origin={:?}",
            carrier.bytes().len(),
            carrier.origin()
        );
        if let CarrierOrigin::CamdStreamParts { parts, .. } = carrier.origin() {
            for part in parts {
                println!(
                    "outer_part={} pts={:?} dts={:?} outer_position={:?} carrier_offset={} bytes={}",
                    part.sequence,
                    part.pts,
                    part.dts,
                    part.outer_source_position,
                    part.carrier_offset,
                    part.length
                );
            }
        }
    }
    if let Some(inner) = inner {
        println!(
            "inner_encoder_diagnostic={:?} selected_indexes={:?} excess_indexes={:?}",
            inner.encoder, inner.selected_track_indexes, inner.excess_track_indexes
        );
        for stream in &inner.streams {
            println!(
                "inner_stream={} id={:?} tag={:?} time_base={}/{}",
                stream.index,
                stream.id,
                stream.codec_tag_string,
                stream.time_base.numerator,
                stream.time_base.denominator
            );
        }
    }
    let mut failed = 0;
    for track in tracks {
        println!(
            "selected_inner_stream={} packets={}",
            track.stream.index,
            track.packets.len()
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
                    "missing outer format encoder".into()
                }
            };
            println!(
                "inner_packet={i} pts={:?} dts={:?} carrier_position={:?} bytes={} status={status:?}",
                packet.pts,
                packet.dts,
                packet.source_position,
                packet.outcome.original_packet().len()
            );
        }
    }
    failed
}

fn run() -> Result<(), String> {
    // Linux paths need not be UTF-8. Decode only the CLI's textual arguments.
    let a: Vec<_> = env::args_os().skip(1).collect();
    let option = a
        .first()
        .filter(|v| v.as_encoded_bytes().starts_with(b"--"))
        .map(|v| text_argument(v, "Option"))
        .transpose()?;
    if option == Some("--raw-panorama") {
        if a.len() != 3 {
            return Err("Usage: dji-reframe --raw-panorama INPUT OUTPUT".into());
        }
        return raw_panorama(Path::new(&a[1]), Path::new(&a[2]));
    }
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
    if option == Some("--metadata-nested") {
        if a.len() != 2 {
            return Err("Usage: dji-reframe --metadata-nested INPUT".into());
        }
        use dji_reframe::metadata::demux::{
            self, Ffprobe, NestedDisposition, NestedLimits, ProbeLimits,
        };
        match demux::inspect_nested(
            Path::new(&a[1]),
            &Ffprobe::new("/usr/bin/ffprobe"),
            &ProbeLimits::default(),
            &NestedLimits::default(),
        ) {
            Ok(report) => {
                let failed = print_nested(
                    Some(&report.outer),
                    report.carrier.as_ref(),
                    report.inner.as_ref(),
                    &report.tracks,
                );
                match report.disposition {
                    NestedDisposition::NoNestedCarrier => println!(
                        "No selected camd stream or matching top-level carrier in this bounded inspection."
                    ),
                    NestedDisposition::NoInnerDirectTracks => println!(
                        "Carrier has no direct inner djmd/xtmd tracks; deeper nesting was not inspected."
                    ),
                    NestedDisposition::InnerDirectTracks => println!(
                        "Selected inner tracks inspected; packet counts above do not imply decoding of empty tracks."
                    ),
                }
                if failed == 0 {
                    return Ok(());
                }
                return Err(format!(
                    "{failed} nested metadata packets could not be decoded; raw bytes retained by library API"
                ));
            }
            Err(error) => {
                print_nested(
                    error.context.outer.as_ref(),
                    error.context.carrier.as_ref(),
                    error.context.inner.as_ref(),
                    &error.context.completed_tracks,
                );
                return Err(error.to_string());
            }
        }
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
            "dji-reframe INPUT OUTPUT [YAW PITCH HFOV]\ndji-reframe --raw-panorama INPUT OUTPUT\ndji-reframe --encoder ENCODER_TAG\ndji-reframe --inspect MP4\ndji-reframe --metadata INPUT\ndji-reframe --metadata-nested INPUT\n--metadata inspects up to two direct djmd/xtmd tracks with FFprobe base64 support.\n--metadata-nested inspects one carrier level using the outer encoder; no recursive processing.\nCamera/Windows compatibility is unverified.\n--inspect scans top-level nested box extents only.\nReframe an already stitched equirectangular video into 1920x1080 H.264.\nDefaults: yaw=0 pitch=0 horizontal FOV=90. Existing output is never overwritten.\n--raw-panorama writes an experimental 2048x1024 H.264/AAC MP4 preview from two matching square camera streams.\nThe preview can have visible seam and lens errors. DJI Studio parity is unverified.\nRequires FFmpeg with v360 and libx264. The raw panorama mode also requires FFprobe."
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
