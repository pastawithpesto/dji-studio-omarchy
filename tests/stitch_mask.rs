#[path = "../src/stitch_mask.rs"]
mod stitch_mask;

use std::path::PathBuf;
use stitch_mask::{DecodedMask, MaskError, MaskErrorKind, MaskLimits, decode_mask_v2};

const FIXTURE_DIR: &str = "tests/fixtures/stitching/masks";
const MAX_RESOURCE_BYTES: usize = 16_777_216;

#[test]
fn all_original_masks_match_input_pins_and_expanded_oracles() {
    let manifest: serde_json::Value =
        serde_json::from_str(include_str!("fixtures/stitching/masks/manifest.json")).unwrap();
    assert_eq!(manifest["reference_build"], "DJI Studio 1.0.0.30839");
    assert_eq!(manifest["records"].as_array().unwrap().len(), 14);

    for record in manifest["records"].as_array().unwrap() {
        let relative = record["fixture_path"].as_str().unwrap();
        let input = std::fs::read(fixture_path(relative)).unwrap();
        assert_eq!(
            input.len(),
            record["input_bytes"].as_u64().unwrap() as usize
        );
        assert_eq!(
            hex(&sha256(&input)),
            record["source_sha256"].as_str().unwrap()
        );

        let width = record["width"].as_u64().unwrap() as u32;
        let height = record["height"].as_u64().unwrap() as u32;
        let expected_len = record["expanded_bytes"].as_u64().unwrap() as usize;
        assert_eq!(expected_len, width as usize * height as usize);
        assert!(expected_len <= MAX_RESOURCE_BYTES);

        let decoded = decode_mask_v2(
            &input,
            MaskLimits {
                max_decoded_bytes: MAX_RESOURCE_BYTES,
            },
        )
        .unwrap();
        assert_eq!(decoded.width, width, "{relative}");
        assert_eq!(decoded.height, height, "{relative}");
        assert_eq!(decoded.bytes.len(), expected_len, "{relative}");
        assert_eq!(
            hex(&sha256(&decoded.bytes)),
            record["expanded_sha256"].as_str().unwrap(),
            "{relative}"
        );
    }
}

#[test]
fn accepts_every_byte_value_and_adjacent_equal_runs() {
    let mut runs = Vec::new();
    for value in 0_u8..=u8::MAX {
        runs.extend_from_slice(&1_i32.to_le_bytes());
        runs.push(value);
    }
    runs.extend_from_slice(&0_i32.to_le_bytes());
    let input = resource(256, 1, &runs);
    let decoded = decode_mask_v2(
        &input,
        MaskLimits {
            max_decoded_bytes: 256,
        },
    )
    .unwrap();
    assert_eq!(decoded.bytes, (0_u8..=u8::MAX).collect::<Vec<_>>());

    let adjacent = resource(2, 1, &[1, 0, 0, 0, 7, 1, 0, 0, 0, 7, 0, 0, 0, 0]);
    assert_eq!(decode(adjacent, 2).bytes, [7, 7]);
}

#[test]
fn reports_header_errors_at_contract_offsets() {
    assert_error(b"pano", MaskErrorKind::Truncated, 0);
    assert_error(b"badmagic", MaskErrorKind::BadMagic, 0);

    let valid = resource(1, 1, &[1, 0, 0, 0, 5, 0, 0, 0, 0]);
    for length in 8..12 {
        assert_error(&valid[..length], MaskErrorKind::Truncated, 8);
    }
    for length in 12..16 {
        assert_error(&valid[..length], MaskErrorKind::Truncated, 12);
    }
    for length in 16..20 {
        assert_error(&valid[..length], MaskErrorKind::Truncated, 16);
    }

    let mut bad_width_missing_height = valid[..16].to_vec();
    bad_width_missing_height[12..16].copy_from_slice(&0_i32.to_le_bytes());
    assert_error(&bad_width_missing_height, MaskErrorKind::Truncated, 16);

    let mut unsupported = valid.clone();
    unsupported[8..12].copy_from_slice(&1_i32.to_le_bytes());
    assert_error(&unsupported, MaskErrorKind::UnsupportedVersion, 8);

    let mut bad_width = valid.clone();
    bad_width[12..16].copy_from_slice(&0_i32.to_le_bytes());
    assert_error(&bad_width, MaskErrorKind::InvalidDimensions, 12);
    let mut bad_height = valid;
    bad_height[16..20].copy_from_slice(&(-1_i32).to_le_bytes());
    assert_error(&bad_height, MaskErrorKind::InvalidDimensions, 16);
}

#[test]
fn reports_truncated_runs_negative_counts_and_extent_errors() {
    let header = header(1, 1);
    assert_error(&header, MaskErrorKind::Truncated, 20);

    let mut missing_count_tail = header.clone();
    missing_count_tail.extend_from_slice(&[1, 0]);
    assert_error(&missing_count_tail, MaskErrorKind::Truncated, 20);

    let mut missing_value = header.clone();
    missing_value.extend_from_slice(&1_i32.to_le_bytes());
    assert_error(&missing_value, MaskErrorKind::Truncated, 24);

    let mut missing_terminator = header.clone();
    missing_terminator.extend_from_slice(&1_i32.to_le_bytes());
    missing_terminator.push(9);
    assert_error(&missing_terminator, MaskErrorKind::Truncated, 25);

    let mut negative = header.clone();
    negative.extend_from_slice(&(-1_i32).to_le_bytes());
    assert_error(&negative, MaskErrorKind::NegativeRun, 20);

    let mut early_zero = header.clone();
    early_zero.extend_from_slice(&0_i32.to_le_bytes());
    assert_error(&early_zero, MaskErrorKind::ExtentMismatch, 20);

    let mut too_long = header;
    too_long.extend_from_slice(&2_i32.to_le_bytes());
    too_long.push(3);
    assert_error(&too_long, MaskErrorKind::RunOverflow, 20);
}

#[test]
fn requires_eof_after_zero_and_checks_allocation_limit_before_expansion() {
    let valid = resource(1, 1, &[1, 0, 0, 0, 5, 0, 0, 0, 0]);
    let mut trailing = valid;
    trailing.push(0xaa);
    assert_error(&trailing, MaskErrorKind::TrailingData, trailing.len() - 1);

    let within_limit = decode(resource(1, 1, &[1, 0, 0, 0, 5, 0, 0, 0, 0]), 1);
    assert_eq!(within_limit.bytes, [5]);
    let at_zero = resource(1, 1, &[1, 0, 0, 0, 5, 0, 0, 0, 0]);
    assert_error_with_limit(&at_zero, 0, MaskErrorKind::AllocationLimit, 12);

    let extent = MAX_RESOURCE_BYTES as i32;
    let maximum = resource(
        4096,
        4096,
        &[
            extent.to_le_bytes().as_slice(),
            &[0x5a],
            &0_i32.to_le_bytes(),
        ]
        .concat(),
    );
    let decoded = decode(maximum.clone(), MAX_RESOURCE_BYTES);
    assert_eq!(decoded.bytes.len(), MAX_RESOURCE_BYTES);
    assert_error_with_limit(
        &maximum,
        MAX_RESOURCE_BYTES - 1,
        MaskErrorKind::AllocationLimit,
        12,
    );
}

#[cfg(target_pointer_width = "32")]
#[test]
fn rejects_dimension_product_overflow_on_32_bit_targets() {
    let input = resource(i32::MAX as u32, i32::MAX as u32, &[]);
    assert_error(&input, MaskErrorKind::SizeOverflow, 12);
}

fn fixture_path(relative: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(FIXTURE_DIR)
        .join(relative)
}

fn header(width: u32, height: u32) -> Vec<u8> {
    let mut input = b"panomask".to_vec();
    input.extend_from_slice(&2_i32.to_le_bytes());
    input.extend_from_slice(&(width as i32).to_le_bytes());
    input.extend_from_slice(&(height as i32).to_le_bytes());
    input
}

fn resource(width: u32, height: u32, runs_and_terminator: &[u8]) -> Vec<u8> {
    let mut input = header(width, height);
    input.extend_from_slice(runs_and_terminator);
    input
}

fn decode(input: Vec<u8>, limit: usize) -> DecodedMask {
    decode_mask_v2(
        &input,
        MaskLimits {
            max_decoded_bytes: limit,
        },
    )
    .unwrap()
}

fn assert_error(input: &[u8], kind: MaskErrorKind, offset: usize) {
    assert_error_with_limit(input, MAX_RESOURCE_BYTES, kind, offset);
}

fn assert_error_with_limit(input: &[u8], limit: usize, kind: MaskErrorKind, offset: usize) {
    let error = decode_mask_v2(
        input,
        MaskLimits {
            max_decoded_bytes: limit,
        },
    )
    .unwrap_err();
    assert_eq!(error, MaskError { kind, offset });
}

// Test-only SHA-256. This avoids adding a production or shared dependency only
// to verify the pinned expanded mask oracles.
fn sha256(input: &[u8]) -> [u8; 32] {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
        0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
        0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
        0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
        0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
        0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
        0xc67178f2,
    ];
    let mut state = [
        0x6a09e667_u32,
        0xbb67ae85,
        0x3c6ef372,
        0xa54ff53a,
        0x510e527f,
        0x9b05688c,
        0x1f83d9ab,
        0x5be0cd19,
    ];
    let bit_len = (input.len() as u64).wrapping_mul(8);
    let padded_len = (input.len() + 9).div_ceil(64) * 64;
    let mut padded = Vec::with_capacity(padded_len);
    padded.extend_from_slice(input);
    padded.push(0x80);
    padded.resize(padded_len - 8, 0);
    padded.extend_from_slice(&bit_len.to_be_bytes());

    let (blocks, remainder) = padded.as_chunks::<64>();
    debug_assert!(remainder.is_empty());
    for block in blocks {
        let mut words = [0_u32; 64];
        let (input_words, remainder) = block.as_chunks::<4>();
        debug_assert!(remainder.is_empty());
        for (index, chunk) in input_words.iter().take(16).enumerate() {
            words[index] = u32::from_be_bytes(*chunk);
        }
        for index in 16..64 {
            let s0 = words[index - 15].rotate_right(7)
                ^ words[index - 15].rotate_right(18)
                ^ (words[index - 15] >> 3);
            let s1 = words[index - 2].rotate_right(17)
                ^ words[index - 2].rotate_right(19)
                ^ (words[index - 2] >> 10);
            words[index] = words[index - 16]
                .wrapping_add(s0)
                .wrapping_add(words[index - 7])
                .wrapping_add(s1);
        }

        let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = state;
        for index in 0..64 {
            let sum1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let choose = (e & f) ^ ((!e) & g);
            let temp1 = h
                .wrapping_add(sum1)
                .wrapping_add(choose)
                .wrapping_add(K[index])
                .wrapping_add(words[index]);
            let sum0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let majority = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = sum0.wrapping_add(majority);
            h = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }
        for (slot, value) in state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
            *slot = slot.wrapping_add(value);
        }
    }

    let mut digest = [0_u8; 32];
    let (chunks, remainder) = digest.as_chunks_mut::<4>();
    debug_assert!(remainder.is_empty());
    for (chunk, word) in chunks.iter_mut().zip(state) {
        chunk.copy_from_slice(&word.to_be_bytes());
    }
    digest
}

fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push(DIGITS[(byte >> 4) as usize] as char);
        output.push(DIGITS[(byte & 0x0f) as usize] as char);
    }
    output
}
