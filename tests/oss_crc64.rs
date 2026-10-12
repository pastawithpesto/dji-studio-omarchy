// Direct inclusion preserves the separate integration owner's src/lib.rs scope.
#[path = "../src/oss_crc64.rs"]
mod oss_crc64;

use oss_crc64::{CombineCRC64, ComputeCRC64};

const POLYNOMIAL: u64 = 0xc96c_5795_d787_0f42;

// Independent oracle: eight individual polynomial steps for each input byte.
// It neither generates nor reads the production lookup table.
fn bitwise_crc(seed: u64, data: &[u8]) -> u64 {
    let mut state = !seed;
    for &byte in data {
        state ^= u64::from(byte);
        for _ in 0..8 {
            let previous_low_bit = state & 1;
            state >>= 1;
            if previous_low_bit == 1 {
                state ^= POLYNOMIAL;
            }
        }
    }
    !state
}

// Independent combine oracle: reflected polynomial products, with bit 63 as
// the multiplicative identity. It uses no columns, matrices or matrix squares.
fn polynomial_product(left: u64, mut right: u64) -> u64 {
    let mut product = 0;
    for bit in (0..64).rev() {
        if left & (1_u64 << bit) != 0 {
            product ^= right;
        }
        right = (right >> 1) ^ if right & 1 == 1 { POLYNOMIAL } else { 0 };
    }
    product
}

fn polynomial_combine(crc1: u64, crc2: u64, mut byte_count: u64) -> u64 {
    if byte_count == 0 {
        return crc1;
    }
    let mut power = 1_u64 << 63;
    let mut zero_byte = 1_u64 << 55;
    while byte_count != 0 {
        if byte_count & 1 != 0 {
            power = polynomial_product(power, zero_byte);
        }
        byte_count >>= 1;
        zero_byte = polynomial_product(zero_byte, zero_byte);
    }
    polynomial_product(power, crc1) ^ crc2
}

fn payload(length: usize) -> Vec<u8> {
    (0..length)
        .map(|i| (i.wrapping_mul(197) + (i >> 3).wrapping_mul(29) + 83) as u8)
        .collect()
}

#[test]
fn empty_input_preserves_every_seed_bit() {
    for bit in 0..64 {
        let seed = 1_u64 << bit;
        assert_eq!(ComputeCRC64(seed, &[]), seed);
        assert_eq!(ComputeCRC64(!seed, &[]), !seed);
    }
    assert_eq!(ComputeCRC64(0, &[]), 0);
    assert_eq!(ComputeCRC64(u64::MAX, &[]), u64::MAX);
}

#[test]
fn zero_second_length_ignores_arbitrary_second_crc() {
    for crc1 in [0, 1, u64::MAX, POLYNOMIAL, 1 << 63] {
        for bit in 0..64 {
            assert_eq!(CombineCRC64(crc1, 1 << bit, 0), crc1);
            assert_eq!(CombineCRC64(crc1, !(1 << bit), 0), crc1);
        }
    }
}

#[test]
fn every_byte_and_seed_bit_matches_bitwise_oracle() {
    for byte in 0..=255 {
        for bit in 0..64 {
            let seed = 1_u64 << bit;
            assert_eq!(ComputeCRC64(seed, &[byte]), bitwise_crc(seed, &[byte]));
        }
    }
}

#[test]
fn lengths_and_arbitrary_seeds_match_bitwise_oracle() {
    let data = payload(4097);
    for length in [0, 1, 7, 8, 9, 15, 16, 17, 255, 256, 257, 4096, 4097] {
        for seed in [0, 1, u64::MAX, 0x0123_4567_89ab_cdef, POLYNOMIAL] {
            assert_eq!(
                ComputeCRC64(seed, &data[..length]),
                bitwise_crc(seed, &data[..length])
            );
        }
    }
}

#[test]
fn arbitrary_combine_words_and_full_width_lengths_match_polynomial_products() {
    let lengths = [
        0,
        1,
        2,
        3,
        7,
        8,
        9,
        255,
        256,
        257,
        u64::from(u32::MAX),
        1 << 32,
        (1 << 32) + 1,
        (1 << 63) - 1,
        1 << 63,
        (1 << 63) + 1,
        u64::MAX,
    ];
    for crc1 in [0, 1, u64::MAX, 0x0123_4567_89ab_cdef, POLYNOMIAL] {
        for crc2 in [0, 1, u64::MAX, 0xfedc_ba98_7654_3210, 1 << 63] {
            for length in lengths {
                assert_eq!(
                    CombineCRC64(crc1, crc2, length),
                    polynomial_combine(crc1, crc2, length),
                    "crc1={crc1:016x} crc2={crc2:016x} length={length:016x}"
                );
            }
        }
    }
}

#[test]
fn every_length_bit_has_a_distinctly_supported_unsigned_path() {
    for bit in 0..64 {
        let length = 1_u64 << bit;
        for crc in [1, 1 << 63, u64::MAX, POLYNOMIAL] {
            assert_eq!(
                CombineCRC64(crc, 0, length),
                polynomial_combine(crc, 0, length)
            );
        }
    }
}

#[test]
fn incremental_and_combined_segments_match_whole_seeded_computation() {
    let data = payload(257);
    for seed in [0, 1, u64::MAX, 0x0123_4567_89ab_cdef, 1 << 63] {
        let whole = ComputeCRC64(seed, &data);
        for split in 0..=data.len() {
            let first = ComputeCRC64(seed, &data[..split]);
            let second = ComputeCRC64(0, &data[split..]);
            assert_eq!(ComputeCRC64(first, &data[split..]), whole);
            assert_eq!(
                CombineCRC64(first, second, (data.len() - split) as u64),
                whole
            );
        }
    }
}

#[test]
fn combine_zero_byte_advance_obeys_composition_for_nonoverflowing_lengths() {
    for (first, second) in [(1, 1), (255, 257), (1 << 32, 17), (1 << 62, 1 << 62)] {
        for crc in [0, 1, u64::MAX, POLYNOMIAL] {
            assert_eq!(
                CombineCRC64(CombineCRC64(crc, 0, first), 0, second),
                CombineCRC64(crc, 0, first + second)
            );
        }
    }
}

fn original_fixture() -> serde_json::Value {
    serde_json::from_str(include_str!(
        "fixtures/oss-crc64/ORIGINAL-EXPORT-FIXTURE.json"
    ))
    .expect("Pinned original-DLL fixture must be valid JSON")
}

fn hex_word(value: &serde_json::Value) -> u64 {
    u64::from_str_radix(value.as_str().unwrap().trim_start_matches("0x"), 16).unwrap()
}

fn reference_payload(pattern: &str, length: usize) -> Vec<u8> {
    let (recipe, start) = match pattern.strip_prefix("tail") {
        Some(start) => ("pattern", start.parse::<usize>().unwrap()),
        None => (pattern, 0),
    };
    (start..start + length)
        .map(|i| match recipe {
            "zero" => 0,
            "ones" => 255,
            "ramp" => i as u8,
            "high" => {
                if i & 1 == 0 {
                    128
                } else {
                    255
                }
            }
            "msg" => b"123456789"[i % 9],
            "pattern" => (i * 37 + (i >> 3) * 11 + 128) as u8,
            other => panic!("Unrecognized reference pattern {other}"),
        })
        .collect()
}

#[test]
fn replay_all_3153_original_compute_export_results() {
    let fixture = original_fixture();
    assert_eq!(fixture["corpus"]["case_count"], 3753);
    assert_eq!(
        fixture["source"]["sha256"],
        "083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1"
    );
    let rows = fixture["corpus"]["compute"].as_array().unwrap();
    assert_eq!(rows.len(), 3153);
    for row in rows {
        let length = usize::try_from(row["length"].as_u64().unwrap()).unwrap();
        let offset = usize::try_from(row["offset"].as_u64().unwrap()).unwrap();
        let data = reference_payload(row["pattern"].as_str().unwrap(), length);
        let mut backing = vec![0; offset];
        backing.extend_from_slice(&data);
        assert_eq!(
            ComputeCRC64(hex_word(&row["seed"]), &backing[offset..]),
            hex_word(&row["expected_result"]),
            "Original Compute export case {}",
            row["id"]
        );
    }
}

#[test]
fn replay_all_600_original_combine_export_results() {
    let fixture = original_fixture();
    let rows = fixture["corpus"]["combine"].as_array().unwrap();
    assert_eq!(rows.len(), 600);
    for row in rows {
        assert_eq!(
            CombineCRC64(
                hex_word(&row["crc1"]),
                hex_word(&row["crc2"]),
                hex_word(&row["length2"])
            ),
            hex_word(&row["expected_result"]),
            "Original Combine export case {}",
            row["id"]
        );
    }
}

#[test]
fn replay_all_24_original_valid_joins_and_incremental_suffixes() {
    let fixture = original_fixture();
    let compute: std::collections::HashMap<_, _> = fixture["corpus"]["compute"]
        .as_array()
        .unwrap()
        .iter()
        .map(|row| (row["id"].as_str().unwrap(), row))
        .collect();
    let joins = fixture["corpus"]["valid_joins"].as_array().unwrap();
    assert_eq!(joins.len(), 24);
    for join in joins {
        let prefix = compute[join["prefix_id"].as_str().unwrap()];
        let suffix = compute[join["suffix_id"].as_str().unwrap()];
        let whole = compute[join["whole_id"].as_str().unwrap()];
        let suffix_length = usize::try_from(suffix["length"].as_u64().unwrap()).unwrap();
        let suffix_bytes = reference_payload(suffix["pattern"].as_str().unwrap(), suffix_length);
        let first_crc = hex_word(&prefix["expected_result"]);
        let expected = hex_word(&whole["expected_result"]);
        assert_eq!(ComputeCRC64(first_crc, &suffix_bytes), expected);
        assert_eq!(
            CombineCRC64(
                first_crc,
                hex_word(&suffix["expected_result"]),
                suffix["length"].as_u64().unwrap()
            ),
            expected
        );
    }
}
