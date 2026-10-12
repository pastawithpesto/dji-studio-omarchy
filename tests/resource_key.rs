// Keep the leaf testable before the integration owner registers the module.
#[path = "../src/resource_key.rs"]
mod resource_key;

use resource_key::{
    BucketCountError, BucketLayout, MAX_BUCKET_REQUEST, bucket_layout, resource_key_hash,
};

fn oracles() -> serde_json::Value {
    serde_json::from_str(include_str!("fixtures/resource-key/ORACLES.json")).unwrap()
}

fn decode_hex(value: &str) -> Vec<u8> {
    assert_eq!(value.len() % 2, 0);
    (0..value.len())
        .step_by(2)
        .map(|offset| u8::from_str_radix(&value[offset..offset + 2], 16).unwrap())
        .collect()
}

#[test]
fn exact_independent_key_vectors() {
    for vector in oracles()["hash_vectors"].as_array().unwrap() {
        let key = decode_hex(vector["key_hex"].as_str().unwrap());
        let expected = u64::from_str_radix(vector["expected_hash"].as_str().unwrap(), 16).unwrap();
        assert_eq!(resource_key_hash(&key), expected, "{}", vector["name"]);
    }
}

#[test]
fn exact_independent_bucket_vectors() {
    for vector in oracles()["bucket_vectors"].as_array().unwrap() {
        let requested = vector["requested"]
            .as_str()
            .unwrap()
            .parse::<u64>()
            .unwrap();
        let expected = if vector["outcome"] == "too_large" {
            Err(BucketCountError::TooLarge { requested })
        } else {
            Ok(BucketLayout {
                count: vector["count"].as_str().unwrap().parse().unwrap(),
                mask: vector["mask"].as_str().unwrap().parse().unwrap(),
            })
        };
        assert_eq!(bucket_layout(requested), expected, "request {requested}");
    }
}

#[test]
fn exact_power_of_two_neighbors_through_the_unsigned_limit() {
    for exponent in 2..=59 {
        let power = 1_u64 << exponent;
        for requested in [power - 1, power] {
            assert_eq!(
                bucket_layout(requested),
                Ok(BucketLayout {
                    count: power,
                    mask: power - 1,
                })
            );
        }
        let requested = power + 1;
        if exponent == 59 {
            assert_eq!(
                bucket_layout(requested),
                Err(BucketCountError::TooLarge { requested })
            );
        } else {
            assert_eq!(
                bucket_layout(requested),
                Ok(BucketLayout {
                    count: 2 * power,
                    mask: 2 * power - 1,
                })
            );
        }
    }
    assert_eq!(MAX_BUCKET_REQUEST, 576_460_752_303_423_488);
}

#[test]
fn hashing_uses_length_delimited_bytes_without_text_normalization() {
    // Fixed oracle values distinguish NUL termination, signed byte extension,
    // and UTF-8-only input policies from the recovered byte loop.
    let vectors = oracles();
    for name in [
        "embedded_nul",
        "high_bit",
        "all_ones_byte",
        "mixed_high",
        "all_byte_values",
    ] {
        let vector = vectors["hash_vectors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|vector| vector["name"] == name)
            .unwrap();
        let bytes = decode_hex(vector["key_hex"].as_str().unwrap());
        let expected = u64::from_str_radix(vector["expected_hash"].as_str().unwrap(), 16).unwrap();
        assert_eq!(resource_key_hash(&bytes), expected);
    }
    assert_ne!(resource_key_hash(b"a\0b"), resource_key_hash(b"a"));
    assert_ne!(resource_key_hash(b"A"), resource_key_hash(b"a"));
}
