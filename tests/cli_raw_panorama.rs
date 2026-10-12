use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    sync::atomic::{AtomicU64, Ordering},
};

struct TestDir(PathBuf);

impl TestDir {
    fn new() -> Self {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        loop {
            let path = std::env::temp_dir().join(format!(
                "dji-raw-panorama-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => panic!("Could not create test directory: {e}"),
            }
        }
    }

    fn path(&self, name: &str) -> PathBuf {
        self.0.join(name)
    }
}

impl Drop for TestDir {
    fn drop(&mut self) {
        // This test owns the directory and all files in it.
        fs::remove_dir_all(&self.0).unwrap();
    }
}

fn checked(command: &mut Command) -> Output {
    let result = command.output().expect("Could not start test process");
    assert!(
        result.status.success(),
        "Process failed: {:?}\n{}",
        command,
        String::from_utf8_lossy(&result.stderr)
    );
    result
}

fn fixture(path: &Path, cameras: &[(u32, u32, u32)], preview: bool, audio: bool) {
    let mut command = Command::new("ffmpeg");
    command.args(["-v", "error", "-nostdin", "-n"]);
    if preview {
        command.args(["-f", "lavfi", "-i", "color=c=green:s=32x32:r=12"]);
    }
    for (width, height, rate) in cameras {
        command.args([
            "-f",
            "lavfi",
            "-i",
            &format!("testsrc2=s={width}x{height}:r={rate}"),
        ]);
    }
    let first_camera = usize::from(preview);
    let first_audio = first_camera + cameras.len();
    if audio {
        command.args([
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:sample_rate=48000",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=880:sample_rate=48000",
        ]);
    }
    if preview {
        command.args(["-map", "0:v:0"]);
    }
    if audio {
        command.args(["-map", &format!("{first_audio}:a:0")]);
    }
    for index in first_camera..first_camera + cameras.len() {
        command.args(["-map", &format!("{index}:v:0")]);
    }
    if audio {
        command.args(["-map", &format!("{}:a:0", first_audio + 1)]);
    }
    command.args(["-c:v", "libx264", "-pix_fmt", "yuv420p"]);
    if preview {
        command.args(["-c:v:0", "mjpeg", "-pix_fmt:v:0", "yuvj420p"]);
    }
    command
        .args([
            "-threads:v",
            "1",
            "-c:a",
            "aac",
            "-t",
            "1",
            "-f",
            "matroska",
        ])
        .arg(path);
    checked(&mut command);
}

fn cli(input: &Path, output: &Path) -> Output {
    Command::new(env!("CARGO_BIN_EXE_dji-reframe"))
        .arg("--raw-panorama")
        .arg(input)
        .arg(output)
        .output()
        .unwrap()
}

fn probe(path: &Path) -> serde_json::Value {
    let result = checked(
        Command::new("ffprobe")
            .args([
                "-v",
                "error",
                "-count_frames",
                "-show_entries",
                "stream=index,codec_type,codec_name,width,height,nb_read_frames,avg_frame_rate",
                "-of",
                "json",
                "-i",
            ])
            .arg(path),
    );
    serde_json::from_slice(&result.stdout).unwrap()
}

fn assert_preview(path: &Path, audio: bool) {
    let inventory = probe(path);
    let streams = inventory["streams"].as_array().unwrap();
    let videos: Vec<_> = streams
        .iter()
        .filter(|s| s["codec_type"] == "video")
        .collect();
    assert_eq!(videos.len(), 1);
    assert_eq!(videos[0]["codec_name"], "h264");
    assert_eq!(videos[0]["width"], 2048);
    assert_eq!(videos[0]["height"], 1024);
    assert_eq!(videos[0]["nb_read_frames"], "12");
    assert_eq!(videos[0]["avg_frame_rate"], "12/1");
    let audios: Vec<_> = streams
        .iter()
        .filter(|s| s["codec_type"] == "audio")
        .collect();
    assert_eq!(audios.len(), usize::from(audio));
    if audio {
        assert_eq!(audios[0]["codec_name"], "aac");
        let decoded = checked(
            Command::new("ffmpeg")
                .args(["-v", "error", "-xerror", "-nostdin", "-i"])
                .arg(path)
                .args([
                    "-map", "0:a:0", "-ar", "8000", "-ac", "1", "-f", "f32le", "-",
                ]),
        );
        let samples: Vec<_> = decoded
            .stdout
            .chunks_exact(4)
            .map(|bytes| f32::from_le_bytes(bytes.try_into().unwrap()))
            .collect();
        assert!(samples.len() >= 4000);
        let middle = &samples[samples.len() / 4..samples.len() * 3 / 4];
        let crossings = middle
            .windows(2)
            .filter(|pair| pair[0] <= 0.0 && pair[1] > 0.0)
            .count();
        let frequency = crossings as f64 * 8000.0 / middle.len() as f64;
        // The first source audio stream is 440 Hz. The second is 880 Hz.
        assert!(
            (400.0..480.0).contains(&frequency),
            "Audio frequency: {frequency}"
        );
    }
    checked(
        Command::new("ffmpeg")
            .args(["-v", "error", "-xerror", "-nostdin", "-i"])
            .arg(path)
            .args(["-map", "0:v:0", "-map", "0:a?", "-f", "null", "-"]),
    );
}

#[test]
fn preview_selects_camera_streams_after_mjpeg_and_audio() {
    let dir = TestDir::new();
    let input = dir.path("input with spaces.osv");
    let output = dir.path("panorama with spaces.mp4");
    fixture(&input, &[(64, 64, 12), (64, 64, 12)], true, true);
    let source = probe(&input);
    assert_eq!(source["streams"][0]["codec_name"], "mjpeg");
    assert_eq!(source["streams"][1]["codec_type"], "audio");
    let result = cli(&input, &output);
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_preview(&output, true);
}

#[test]
fn preview_accepts_camera_streams_without_audio() {
    let dir = TestDir::new();
    let input = dir.path("silent.osv");
    let output = dir.path("silent.mp4");
    fixture(&input, &[(64, 64, 12), (64, 64, 12)], false, false);
    let result = cli(&input, &output);
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_preview(&output, false);
}

#[test]
fn preview_rejects_inputs_without_a_clear_camera_pair() {
    let dir = TestDir::new();
    let cases: &[&[(u32, u32, u32)]] = &[
        &[(64, 64, 12)],
        &[(64, 64, 12), (64, 64, 12), (64, 64, 12)],
        &[(64, 32, 12), (64, 32, 12)],
        &[(64, 64, 12), (32, 32, 12)],
        &[(64, 64, 12), (64, 64, 24)],
    ];
    for (i, cameras) in cases.iter().enumerate() {
        let input = dir.path(&format!("invalid-{i}.osv"));
        let output = dir.path(&format!("invalid-{i}.mp4"));
        fixture(&input, cameras, true, false);
        let result = cli(&input, &output);
        assert!(!result.status.success());
        assert!(String::from_utf8_lossy(&result.stderr).contains(
            "Raw panorama input must have exactly two matching square camera video streams"
        ));
        assert!(!output.exists());
    }
}

#[test]
fn preview_preserves_existing_output_before_probe() {
    let dir = TestDir::new();
    let input = dir.path("not-media.osv");
    let output = dir.path("existing.mp4");
    fs::write(&input, b"Not a media file").unwrap();
    fs::write(&output, b"Keep these bytes").unwrap();
    let result = cli(&input, &output);
    assert!(!result.status.success());
    assert_eq!(result.stderr, b"Output already exists\n");
    assert_eq!(fs::read(&output).unwrap(), b"Keep these bytes");
}

#[test]
fn preview_rejects_invalid_media_and_wrong_argument_count() {
    let dir = TestDir::new();
    let input = dir.path("invalid.osv");
    let output = dir.path("invalid.mp4");
    fs::write(&input, b"Not a media file").unwrap();
    let result = cli(&input, &output);
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).starts_with("FFprobe failed:"));
    assert!(!output.exists());
    let result = Command::new(env!("CARGO_BIN_EXE_dji-reframe"))
        .args(["--raw-panorama", "input.osv"])
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert_eq!(
        result.stderr,
        b"Usage: dji-reframe --raw-panorama INPUT OUTPUT\n"
    );
}
