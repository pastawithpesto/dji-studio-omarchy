//! Scalar calculations recovered from DJI Studio 1.0.0.30839 resource_sdk.dll.
//!
//! REA 6.4.0/Ghidra 12.1.4 and original machine bytes support the contract in
//! docs/tasks/resource-key-rea640.md. These helpers do not allocate buckets,
//! mutate a container, normalize text, or reproduce the vendor string ABI.

/// Maximum request admitted by the unsigned guard at 0x180005d57.
pub const MAX_BUCKET_REQUEST: u64 = 1 << 59;

/// The count and mask calculated before the original bucket allocation.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BucketLayout {
    pub count: u64,
    pub mask: u64,
}

/// Native typed error policy for the original C++ length-error branch.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BucketCountError {
    TooLarge { requested: u64 },
}

/// Compute the SDK's FNV-1a64 hash over the exact supplied key bytes.
///
/// The original loop at 0x1800033e4..0x180003413 zero-extends each byte,
/// XORs it into the accumulator, and retains the low 64 product bits.
/// The original string length controls the loop; NUL is ordinary data.
/// A safe slice replaces the original MSVC string pointer and size fields.
pub fn resource_key_hash(key: &[u8]) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    for &byte in key {
        hash = (hash ^ u64::from(byte)).wrapping_mul(0x0100_0000_01b3);
    }
    hash
}

/// Calculate the original rehash count and mask without allocating memory.
///
/// Instructions at 0x180005d65..0x180005d85 perform wrapping subtraction,
/// OR with 1, BSR plus 1, and a 64-bit SHL with a masked count.
/// Request 0 therefore gives count 1; request 1 gives count 2. Other admitted
/// requests round up to a power of two with a minimum count of 2.
///
/// A typed error replaces the original std::_Xlength_error branch. An Ok
/// result does not establish that the original allocation or rehash succeeds.
pub fn bucket_layout(requested: u64) -> Result<BucketLayout, BucketCountError> {
    if requested > MAX_BUCKET_REQUEST {
        return Err(BucketCountError::TooLarge { requested });
    }
    let bit_scan_input = requested.wrapping_sub(1) | 1;
    let shift = u64::BITS - bit_scan_input.leading_zeros();
    let count = 1_u64.wrapping_shl(shift);
    Ok(BucketLayout {
        count,
        mask: count - 1,
    })
}
