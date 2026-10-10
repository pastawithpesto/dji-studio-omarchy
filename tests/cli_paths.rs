#![cfg(unix)]

use std::{
    ffi::{OsStr, OsString},
    fs,
    os::unix::{ffi::OsStrExt, ffi::OsStringExt, fs::PermissionsExt},
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
                "dji-reframe-cli-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match fs::create_dir(&path) {
                Ok(()) => return Self(path),
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => panic!("create test directory: {e}"),
            }
        }
    }

    fn path(&self, name: impl AsRef<OsStr>) -> PathBuf {
        self.0.join(name.as_ref())
    }

    fn input(&self) -> PathBuf {
        let input = self.path(OsString::from_vec(b"input-\xff.mp4".to_vec()));
        // Independently specified ISO-BMFF size/tag/payload, not camera media.
        fs::write(&input, b"\0\0\0\x0cMETAdata").unwrap();
        input
    }

    fn mock_ffmpeg(&self) -> PathBuf {
        let executable = self.path("ffmpeg");
        fs::write(
            &executable,
            b"#!/bin/sh\nprintf '%s\\0' \"$@\" > \"$DJI_TEST_FFMPEG_ARGS\"\n",
        )
        .unwrap();
        fs::set_permissions(&executable, fs::Permissions::from_mode(0o700)).unwrap();
        self.path("ffmpeg-args.bin")
    }

    fn command(&self, capture: &Path) -> Command {
        let mut command = cli();
        // Configure only the child; parallel tests never mutate global env.
        command
            .env("PATH", &self.0)
            .env("DJI_TEST_FFMPEG_ARGS", capture);
        command
    }
}

impl Drop for TestDir {
    fn drop(&mut self) {
        // This exact directory was created and exclusively owned by this test.
        fs::remove_dir_all(&self.0).unwrap();
    }
}

fn cli() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dji-reframe"))
}

fn assert_error(output: Output, message: &str) {
    assert_eq!(output.status.code(), Some(1));
    assert_eq!(output.stderr, format!("{message}\n").as_bytes());
    assert!(output.stdout.is_empty());
}

#[test]
fn inspect_opens_a_real_non_utf8_path() {
    let dir = TestDir::new();
    let input = dir.input();
    assert!(input.to_str().is_none());
    let output = cli().arg("--inspect").arg(&input).output().unwrap();
    assert!(output.status.success(), "{:?}", output);
    assert_eq!(output.stdout, b"META offset=8 bytes=4\n");
    assert!(output.stderr.is_empty());
}

#[test]
fn export_preserves_path_bytes_and_existing_command_defaults() {
    let dir = TestDir::new();
    let input = dir.input();
    let output = dir.path(OsString::from_vec(b"output-\xfe.mp4".to_vec()));
    let capture = dir.mock_ffmpeg();
    let result = dir
        .command(&capture)
        .arg(&input)
        .arg(&output)
        .output()
        .unwrap();
    assert!(result.status.success(), "{:?}", result);
    assert!(result.stderr.is_empty());
    let bytes = fs::read(capture).unwrap();
    assert_eq!(bytes.last(), Some(&0));
    let arguments: Vec<_> = bytes[..bytes.len() - 1].split(|b| *b == 0).collect();
    assert_eq!(arguments.len(), 21);
    assert!(arguments[9].starts_with(
        b"v360=input=equirect:output=flat:w=1920:h=1080:yaw=0:pitch=0:h_fov=90:v_fov="
    ));
    let expected: [&[u8]; 21] = [
        b"-nostdin",
        b"-n",
        b"-i",
        input.as_os_str().as_bytes(),
        b"-map",
        b"0:v:0",
        b"-map",
        b"0:a?",
        b"-vf",
        arguments[9],
        b"-c:v",
        b"libx264",
        b"-crf",
        b"20",
        b"-pix_fmt",
        b"yuv420p",
        b"-c:a",
        b"aac",
        b"-movflags",
        b"+faststart",
        output.as_os_str().as_bytes(),
    ];
    assert_eq!(arguments, expected);
}

#[test]
fn non_utf8_text_arguments_return_cli_errors() {
    let invalid = OsString::from_vec(vec![0xff]);
    assert_error(
        cli().arg("--encoder").arg(&invalid).output().unwrap(),
        "Encoder tag must be valid UTF-8",
    );
    assert_error(
        cli()
            .arg(OsString::from_vec(b"--\xff".to_vec()))
            .output()
            .unwrap(),
        "Option must be valid UTF-8",
    );
    let dir = TestDir::new();
    assert_error(
        cli()
            .arg(dir.input())
            .arg(dir.path("output.mp4"))
            .arg(&invalid)
            .args(["0", "90"])
            .output()
            .unwrap(),
        "Angle must be valid UTF-8",
    );
}

#[test]
fn normal_encoder_and_angle_errors_are_preserved() {
    let output = cli().args(["--encoder", "Osmo 360"]).output().unwrap();
    assert!(output.status.success(), "{:?}", output);
    assert_eq!(
        output.stdout,
        b"product=9 protobuf_package=oqb101 (schema registry only; decoding pending)\n"
    );
    assert!(output.stderr.is_empty());
    let dir = TestDir::new();
    assert_error(
        cli()
            .arg(dir.input())
            .arg(dir.path("output.mp4"))
            .args(["wrong", "0", "90"])
            .output()
            .unwrap(),
        "Invalid angle: wrong",
    );
}

#[test]
fn existing_non_utf8_output_is_refused_before_ffmpeg() {
    let dir = TestDir::new();
    let input = dir.input();
    let output = dir.path(OsString::from_vec(b"output-\xfe.mp4".to_vec()));
    fs::write(&output, b"keep existing bytes").unwrap();
    let capture = dir.mock_ffmpeg();
    assert_error(
        dir.command(&capture)
            .arg(&input)
            .arg(&output)
            .output()
            .unwrap(),
        "Output already exists",
    );
    assert_eq!(fs::read(output).unwrap(), b"keep existing bytes");
    assert!(!capture.exists());
}
