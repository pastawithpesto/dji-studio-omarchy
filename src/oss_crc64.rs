//! Bounded translation of AlibabaCloud::OSS CRC64 arithmetic.
//!
//! Original build 1.0.0.30839, `alibabacloud-oss-cpp-sdk.dll`, SHA-256
//! `083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1`.
//! The exact original-byte contract and independent approval are recorded in
//! `docs/evidence/oss-crc64/contract.md`.
//!
//! Slices replace the native pointer/count pair. The immutable compile-time
//! table replaces process startup initialization. These are independent Rust
//! safety and lifecycle choices, not C++ ABI or invalid-pointer equivalence.

const POLYNOMIAL: u64 = 0xc96c_5795_d787_0f42;
const TABLE: [u64; 256] = make_table();

// Original generator: RVA 0x1b49c0..0x1b4b4f. Only its base table is needed
// for the equivalent byte recurrence, independent of host byte order/alignment.
const fn make_table() -> [u64; 256] {
    let mut table = [0; 256];
    let mut index = 0;
    while index < table.len() {
        let mut crc = index as u64;
        let mut bit = 0;
        while bit < 8 {
            crc = if crc & 1 != 0 {
                (crc >> 1) ^ POLYNOMIAL
            } else {
                crc >> 1
            };
            bit += 1;
        }
        table[index] = crc;
        index += 1;
    }
    table
}

/// Update an incoming CRC with bytes in their slice order.
///
/// Original name: `AlibabaCloud::OSS::ComputeCRC64`. Export RVA 0xc9a0
/// reaches the arithmetic body at RVA 0x1b4bc0..0x1b4ce4 through four jumps.
/// The reflected polynomial is 0xC96C5795D7870F42. The incoming seed and
/// final internal state are both complemented. An empty slice returns `seed`.
/// For incremental computation, pass the previous returned CRC as `seed`.
///
/// The slice length replaces the original unsigned byte count. Native pointer
/// validity, buffer allocation, alignment and foreign calling conventions are
/// outside this safe Rust API.
#[allow(non_snake_case)]
pub fn ComputeCRC64(seed: u64, data: &[u8]) -> u64 {
    let mut crc = !seed;
    for &byte in data {
        let index = usize::from((crc as u8) ^ byte);
        crc = TABLE[index] ^ (crc >> 8);
    }
    !crc
}

/// Combine two CRC words using the unsigned byte length of the second segment.
///
/// Original name: `AlibabaCloud::OSS::CombineCRC64`. Export RVA 0x55c4
/// reaches the arithmetic body at RVA 0x1b4850..0x1b4975 through four jumps.
/// A zero `len2` returns `crc1` and ignores `crc2`. Every u64 length is
/// supported with at most 64 length-bit steps and fixed stack storage.
///
/// For concatenation, compute `crc2` with seed zero over the second segment;
/// `crc1` may come from any seed. Arbitrary CRC words remain valid inputs,
/// but their combination need not describe an actual byte concatenation.
#[allow(non_snake_case)]
pub fn CombineCRC64(mut crc1: u64, crc2: u64, mut len2: u64) -> u64 {
    if len2 == 0 {
        return crc1;
    }

    // The original one-zero-bit operator has its polynomial in column zero
    // and the remaining columns 1, 2, ..., 1 << 62.
    let mut odd = [0; 64];
    odd[0] = POLYNOMIAL;
    let mut row = 1;
    for column in &mut odd[1..] {
        *column = row;
        row <<= 1;
    }
    let mut even = matrix_square(&odd); // Two zero bits.
    odd = matrix_square(&even); // Four zero bits.

    loop {
        even = matrix_square(&odd); // First iteration advances one zero byte.
        if len2 & 1 != 0 {
            crc1 = matrix_times(&even, crc1);
        }
        len2 >>= 1;
        if len2 == 0 {
            break;
        }

        odd = matrix_square(&even);
        if len2 & 1 != 0 {
            crc1 = matrix_times(&odd, crc1);
        }
        len2 >>= 1;
        if len2 == 0 {
            break;
        }
    }
    crc1 ^ crc2
}

// Original helper: RVA 0x1b4d90..0x1b4da8.
fn matrix_times(matrix: &[u64; 64], mut vector: u64) -> u64 {
    let mut sum = 0;
    let mut index = 0;
    while vector != 0 {
        if vector & 1 != 0 {
            sum ^= matrix[index];
        }
        vector >>= 1;
        index += 1;
    }
    sum
}

// Original helper: RVA 0x1b4d40..0x1b4d7d.
fn matrix_square(matrix: &[u64; 64]) -> [u64; 64] {
    let mut square = [0; 64];
    for (output, &column) in square.iter_mut().zip(matrix) {
        *output = matrix_times(matrix, column);
    }
    square
}
