//! Signed decimal bytes recovered from resource_sdk.dll 1.0.0.30839.
//! The safe buffer and atomic errors are independent native policy.

/// Maximum ASCII length of any signed 32-bit decimal value.
pub const MAX_I32_DECIMAL_BYTES: usize = 11;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DecimalWriteError {
    InvalidLength { used: usize, capacity: usize },
    InsufficientCapacity { required: usize, available: usize },
}

/// Append the signed decimal representation and return the new used length.
///
/// Preserve the prefix and remaining suffix. Write no NUL terminator.
/// On error, leave the entire output unchanged. This function does not allocate
/// or reproduce the original object layout, capacity growth or allocator.
pub fn append_i32_decimal(
    output: &mut [u8],
    used: usize,
    value: i32,
) -> Result<usize, DecimalWriteError> {
    if used > output.len() {
        return Err(DecimalWriteError::InvalidLength {
            used,
            capacity: output.len(),
        });
    }
    // The original MOVSXD/NEG sequence widens before negating INT_MIN.
    let mut magnitude = i64::from(value).unsigned_abs();
    let mut digits = [0_u8; MAX_I32_DECIMAL_BYTES];
    let mut start = digits.len();
    loop {
        start -= 1;
        digits[start] = b'0' + (magnitude % 10) as u8;
        magnitude /= 10;
        if magnitude == 0 {
            break;
        }
    }
    if value < 0 {
        start -= 1;
        digits[start] = b'-';
    }
    let required = digits.len() - start;
    let available = output.len() - used;
    if required > available {
        return Err(DecimalWriteError::InsufficientCapacity {
            required,
            available,
        });
    }
    let end = used + required;
    output[used..end].copy_from_slice(&digits[start..]);
    Ok(end)
}
