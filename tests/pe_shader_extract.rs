use std::fs;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT: AtomicU64 = AtomicU64::new(0);

// Independent minimal PE32+ fixture with nonidentity RVA/file mappings.
fn fixture() -> Vec<u8> {
    let mut b = vec![0; 0x600];
    b[..2].copy_from_slice(b"MZ");
    b[0x3c..0x40].copy_from_slice(&0x80_u32.to_le_bytes());
    b[0x80..0x84].copy_from_slice(b"PE\0\0");
    b[0x84..0x86].copy_from_slice(&0x8664_u16.to_le_bytes());
    b[0x86..0x88].copy_from_slice(&2_u16.to_le_bytes());
    b[0x94..0x96].copy_from_slice(&0xf0_u16.to_le_bytes());
    b[0x98..0x9a].copy_from_slice(&0x20b_u16.to_le_bytes());
    b[0xb0..0xb8].copy_from_slice(&0x180000000_u64.to_le_bytes());
    b[0xd4..0xd8].copy_from_slice(&0x200_u32.to_le_bytes());
    for (o, rva, raw) in [(0x188, 0x1000_u32, 0x200_u32), (0x1b0, 0x3000, 0x400)] {
        b[o..o + 6].copy_from_slice(b".rdata");
        b[o + 8..o + 12].copy_from_slice(&0x200_u32.to_le_bytes());
        b[o + 12..o + 16].copy_from_slice(&rva.to_le_bytes());
        b[o + 16..o + 20].copy_from_slice(&0x200_u32.to_le_bytes());
        b[o + 20..o + 24].copy_from_slice(&raw.to_le_bytes());
    }
    b[0x210..0x218].copy_from_slice(&0x180003020_u64.to_le_bytes());
    b[0x420..0x42d].copy_from_slice(b"shader\n\"text\"");
    b
}

fn invoke(bytes: &[u8], address: &str) -> Output {
    let dir = std::env::temp_dir().join(format!(
        "pe-shader-test-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&dir).unwrap();
    let path = dir.join("fixture.dll");
    fs::write(&path, bytes).unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_pe_shader_extract"))
        .arg(path)
        .arg(address)
        .output()
        .unwrap();
    fs::remove_dir_all(dir).unwrap();
    output
}

fn fails(bytes: &[u8], address: &str, message: &str) {
    let output = invoke(bytes, address);
    assert!(!output.status.success());
    assert!(output.stdout.is_empty());
    let error = String::from_utf8(output.stderr).unwrap();
    assert!(error.contains(message), "unexpected error: {error}");
}

#[test]
fn follows_absolute_pointer_between_distinct_sections_and_preserves_text() {
    let output = invoke(&fixture(), "0x180001010");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["slot_file_offset"], 0x210);
    assert_eq!(d["source_va"], "0x180003020");
    assert_eq!(d["source_file_offset"], 0x420);
    assert_eq!(d["source_bytes"], 13);
    assert_eq!(d["terminator_file_offset"], 0x42d);
    assert_eq!(d["source_text"], "shader\n\"text\"");
}

#[test]
fn maps_headers_and_accepts_decimal_addresses() {
    let mut b = fixture();
    b[0x50..0x58].copy_from_slice(&0x180003020_u64.to_le_bytes());
    let output = invoke(&b, &0x180000050_u64.to_string());
    assert!(output.status.success());
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["slot_file_offset"], 0x50);
}

#[test]
fn rejects_bad_headers_and_section_extents() {
    fails(&[], "0x180001010", "truncated");
    let b = fixture();
    fails(&b[..0x3f], "0x180001010", "truncated");
    for (offset, value, message) in [
        (0, 0, "DOS signature"),
        (0x80, 0, "PE signature"),
        (0x84, 0, "AMD64"),
        (0x98, 0, "PE32+"),
        (0x86, 0, "section count"),
        (0x94, 0, "short PE32+"),
    ] {
        let mut bad = b.clone();
        bad[offset] = value;
        fails(&bad, "0x180001010", message);
    }
    let mut bad = b.clone();
    bad[0x1c4..0x1c8].copy_from_slice(&0x580_u32.to_le_bytes());
    fails(&bad, "0x180001010", "truncated");
    let mut bad = b.clone();
    bad[0x1bc..0x1c0].copy_from_slice(&0x1100_u32.to_le_bytes());
    fails(&bad, "0x180001010", "overlapping virtual");
    let mut bad = b.clone();
    bad[0x1bc..0x1c0].copy_from_slice(&0xfffffff0_u32.to_le_bytes());
    fails(&bad, "0x180001010", "address extent overflow");
    let mut bad = b;
    bad[0x1c4..0x1c8].copy_from_slice(&0x100_u32.to_le_bytes());
    fails(&bad, "0x180001010", "raw data overlaps headers");
}

#[test]
fn rejects_unmapped_virtual_only_and_cross_region_pointers() {
    let b = fixture();
    fails(&b, "0x17fffffff", "below image base");
    fails(&b, "0x280000000", "32-bit RVA");
    fails(&b, "0x180002000", "no mapped region");
    fails(&b, "0x1800011fc", "not file-backed");
    let mut virtual_only = b.clone();
    virtual_only[0x190..0x194].copy_from_slice(&0x400_u32.to_le_bytes());
    fails(&virtual_only, "0x180001300", "not file-backed");
    let mut bad_target = b;
    bad_target[0x210..0x218].copy_from_slice(&0x180002000_u64.to_le_bytes());
    fails(&bad_target, "0x180001010", "no mapped region");
}

#[test]
fn respects_terminator_region_boundaries_and_utf8() {
    let mut b = fixture();
    b[0x420..].fill(b'x');
    fails(&b, "0x180001010", "unterminated");
    b[0x5ff] = 0;
    let output = invoke(&b, "0x180001010");
    assert!(output.status.success());
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["source_bytes"], 0x1df);
    b[0x420] = 0xff;
    fails(&b, "0x180001010", "not UTF-8");
    b[0x420] = 0;
    let output = invoke(&b, "0x180001010");
    assert!(output.status.success());
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["source_bytes"], 0);
}

#[test]
fn rejects_invalid_address_syntax() {
    for address in ["-1", "0x", "18446744073709551616", "0x10000000000000000"] {
        fails(&fixture(), address, "unsigned decimal or 0x hexadecimal");
    }
}

#[test]
fn source_limit_is_inclusive_and_does_not_scan_beyond_it() {
    const LIMIT: usize = 1024 * 1024;
    let mut b = fixture();
    let raw_size = LIMIT as u32 + 2;
    b.resize(0x400 + raw_size as usize, b'x');
    b[0x1b8..0x1bc].copy_from_slice(&raw_size.to_le_bytes());
    b[0x1c0..0x1c4].copy_from_slice(&raw_size.to_le_bytes());
    b[0x210..0x218].copy_from_slice(&0x180003000_u64.to_le_bytes());
    b[0x400..].fill(b'x');
    b[0x400 + LIMIT] = 0;
    let output = invoke(&b, "0x180001010");
    assert!(output.status.success());
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["source_bytes"], LIMIT);
    b[0x400 + LIMIT] = b'x';
    b[0x400 + LIMIT + 1] = 0;
    fails(&b, "0x180001010", "1 MiB native limit");
}

#[test]
fn selected_truncated_prefixes_fail_without_panicking() {
    let b = fixture();
    for length in [
        1, 2, 0x3c, 0x40, 0x80, 0x84, 0x98, 0x188, 0x1d8, 0x200, 0x5ff,
    ] {
        let output = invoke(&b[..length], "0x180001010");
        assert_eq!(output.status.code(), Some(1));
        assert!(output.stdout.is_empty());
        assert!(
            !String::from_utf8(output.stderr)
                .unwrap()
                .contains("panicked")
        );
    }
}

#[test]
fn refuses_oversized_and_nonregular_files() {
    let dir = std::env::temp_dir().join(format!(
        "pe-shader-limit-test-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&dir).unwrap();
    let path = dir.join("oversized.dll");
    let file = fs::File::create(&path).unwrap();
    file.set_len(256 * 1024 * 1024 + 1).unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_pe_shader_extract"))
        .arg(&path)
        .arg("0x180001010")
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(output.stdout.is_empty());
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("256 MiB")
    );
    let output = Command::new(env!("CARGO_BIN_EXE_pe_shader_extract"))
        .arg(&dir)
        .arg("0x180001010")
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("regular file")
    );
    fs::remove_dir_all(dir).unwrap();
}

#[cfg(unix)]
#[test]
fn preserves_non_utf8_input_paths() {
    use std::os::unix::ffi::OsStringExt;
    let dir = std::env::temp_dir().join(format!(
        "pe-shader-path-test-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&dir).unwrap();
    let path = dir.join(std::ffi::OsString::from_vec(b"shader-\xff.dll".to_vec()));
    fs::write(&path, fixture()).unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_pe_shader_extract"))
        .arg(&path)
        .arg("0x180001010")
        .output()
        .unwrap();
    assert!(output.status.success());
    let d: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(d["source_text"], "shader\n\"text\"");
    fs::remove_dir_all(dir).unwrap();
}
