//! Real CLI checks and independent compressed-run histogram oracles.

use serde_json::Value;
use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::OnceLock;

fn tool() -> &'static Path {
    static TOOL: OnceLock<PathBuf> = OnceLock::new();
    TOOL.get_or_init(|| {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let executable = root
            .join("target")
            .join(format!("mask-inspect-cli-test-{}", std::process::id()));
        fs::create_dir_all(executable.parent().unwrap()).unwrap();
        let result = Command::new("rustc")
            .args(["--edition=2024", "-O", "-D", "warnings"])
            .arg(root.join("tools/stitch_mask_inspect.rs"))
            .arg("-o")
            .arg(&executable)
            .output()
            .unwrap();
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        executable
    })
}

struct Temporary(PathBuf);

impl Temporary {
    fn new(name: &str) -> Self {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("target")
            .join(format!("mask-inspect-{}-{name}", std::process::id()));
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::create_dir(&path).unwrap();
        Self(path)
    }

    fn write(&self, name: &OsStr, bytes: &[u8]) -> PathBuf {
        let path = self.0.join(name);
        fs::write(&path, bytes).unwrap();
        path
    }
}

impl Drop for Temporary {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

fn resource(runs: &[(i32, u8)]) -> Vec<u8> {
    let mut bytes = b"panomask".to_vec();
    for field in [2_i32, 2, 2] {
        bytes.extend_from_slice(&field.to_le_bytes());
    }
    for &(count, value) in runs {
        bytes.extend_from_slice(&count.to_le_bytes());
        bytes.push(value);
    }
    bytes.extend_from_slice(&0_i32.to_le_bytes());
    bytes
}

fn inspect(path: &Path, limit: Option<&str>) -> Output {
    let mut command = Command::new(tool());
    command.arg(path);
    if let Some(limit) = limit {
        command.arg(limit);
    }
    command.output().unwrap()
}

#[test]
fn cli_reports_intermediate_byte_values_and_preserves_input() {
    let directory = Temporary::new("valid");
    let bytes = resource(&[(2, 0), (1, 128), (1, 255)]);
    let path = directory.write(OsStr::new("mask with spaces.bin"), &bytes);
    let result = inspect(&path, Some("4"));
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(result.stderr.is_empty());
    let report: Value = serde_json::from_slice(&result.stdout).unwrap();
    assert_eq!(report["format_version"], 2);
    assert_eq!(report["width"], 2);
    assert_eq!(report["height"], 2);
    assert_eq!(report["encoded_bytes"], bytes.len());
    assert_eq!(report["decoded_bytes"], 4);
    let counts = report["byte_counts"].as_array().unwrap();
    assert_eq!(counts.len(), 256);
    for (value, count) in counts.iter().enumerate() {
        assert_eq!(
            count.as_u64().unwrap(),
            match value {
                0 => 2,
                128 | 255 => 1,
                _ => 0,
            }
        );
    }
    assert_eq!(fs::read(path).unwrap(), bytes);
}

#[test]
fn malformed_input_and_decoded_limit_fail_without_partial_json() {
    let directory = Temporary::new("errors");
    let valid = resource(&[(4, 255)]);
    let path = directory.write(OsStr::new("valid.bin"), &valid);
    let limited = inspect(&path, Some("3"));
    assert_eq!(limited.status.code(), Some(1));
    assert!(limited.stdout.is_empty());
    assert!(String::from_utf8_lossy(&limited.stderr).contains("AllocationLimit at byte 12"));
    let mut trailing = valid.clone();
    trailing.push(0);
    let path = directory.write(OsStr::new("trailing.bin"), &trailing);
    let rejected = inspect(&path, None);
    assert_eq!(rejected.status.code(), Some(1));
    assert!(rejected.stdout.is_empty());
    assert!(String::from_utf8_lossy(&rejected.stderr).contains("TrailingData at byte 29"));
    assert_eq!(fs::read(path).unwrap(), trailing);
}

#[test]
fn cli_distinguishes_usage_help_and_io_errors() {
    let missing_args = Command::new(tool()).output().unwrap();
    assert_eq!(missing_args.status.code(), Some(2));
    assert!(missing_args.stdout.is_empty());
    let help = Command::new(tool()).arg("--help").output().unwrap();
    assert!(help.status.success());
    assert!(String::from_utf8_lossy(&help.stdout).contains("MAX_DECODED_BYTES"));
    let directory = Temporary::new("usage");
    let missing = directory.0.join("missing.bin");
    let io_error = inspect(&missing, None);
    assert_eq!(io_error.status.code(), Some(1));
    assert!(io_error.stdout.is_empty());
    for limit in ["0", "-1", "x", "184467440737095516160"] {
        let result = inspect(&missing, Some(limit));
        assert_eq!(result.status.code(), Some(2));
        assert!(result.stdout.is_empty());
    }
}

#[test]
fn oversized_encoded_input_is_rejected_before_decoding() {
    let directory = Temporary::new("size");
    let path = directory.0.join("sparse.bin");
    fs::File::create(&path)
        .unwrap()
        .set_len(64 * 1024 * 1024 + 1)
        .unwrap();
    let result = inspect(&path, None);
    assert_eq!(result.status.code(), Some(1));
    assert!(result.stdout.is_empty());
    assert!(String::from_utf8_lossy(&result.stderr).contains("encoded byte limit"));
    assert_eq!(fs::metadata(path).unwrap().len(), 64 * 1024 * 1024 + 1);
}

#[cfg(unix)]
#[test]
fn native_path_argument_can_contain_non_utf8_bytes() {
    use std::os::unix::ffi::OsStrExt;
    let directory = Temporary::new("native-path");
    let path = directory.write(OsStr::from_bytes(b"mask-\xff.bin"), &resource(&[(4, 7)]));
    let result = inspect(&path, None);
    assert!(result.status.success());
    let report: Value = serde_json::from_slice(&result.stdout).unwrap();
    assert_eq!(report["byte_counts"][7], 4);
}

#[test]
fn every_original_mask_matches_an_independent_compressed_histogram() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/stitching/masks");
    let manifest: Value =
        serde_json::from_slice(&fs::read(root.join("manifest.json")).unwrap()).unwrap();
    let records = manifest["records"].as_array().unwrap();
    assert_eq!(records.len(), 14);
    for record in records {
        let path = root.join(record["fixture_path"].as_str().unwrap());
        let source = fs::read(&path).unwrap();
        // Count weighted compressed records without expanding or calling the decoder.
        let mut expected = [0_u64; 256];
        let mut cursor = 20;
        loop {
            let count = i32::from_le_bytes(source[cursor..cursor + 4].try_into().unwrap());
            cursor += 4;
            if count == 0 {
                break;
            }
            assert!(count > 0);
            expected[usize::from(source[cursor])] += count as u64;
            cursor += 1;
        }
        assert_eq!(cursor, source.len());
        let result = inspect(&path, None);
        assert!(
            result.status.success(),
            "{}: {}",
            path.display(),
            String::from_utf8_lossy(&result.stderr)
        );
        let report: Value = serde_json::from_slice(&result.stdout).unwrap();
        assert_eq!(report["width"], record["width"]);
        assert_eq!(report["height"], record["height"]);
        assert_eq!(report["decoded_bytes"], record["expanded_bytes"]);
        assert_eq!(report["encoded_bytes"], record["input_bytes"]);
        for (value, count) in expected.iter().enumerate() {
            assert_eq!(report["byte_counts"][value].as_u64().unwrap(), *count);
        }
        assert_eq!(
            expected.iter().sum::<u64>(),
            record["expanded_bytes"].as_u64().unwrap()
        );
        assert_eq!(fs::read(path).unwrap(), source);
    }
}
