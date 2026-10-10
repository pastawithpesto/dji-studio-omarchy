//! Bounded byte transform for opaque UI resources.
//!
//! The mask and byte loops follow DJI Studio 1.0.0.30839 helpers
//! `0x1406853e0` and `0x140670e90`, reviewed in UI-RESOURCE-CONTRACT.md
//! (SHA256 12435409a389671372f7656e07684c4967516f95236f189e42d332afe5dfe243).
//! Injected arrays, fresh ownership, size limits and errors are independent
//! native policies. Decoding does not validate integrity, parse RCC or load QML.

/// Independent native input limit; not a recovered vendor file limit.
pub const MAX_UI_RESOURCE_BYTES: usize = 16 * 1024 * 1024;

/// Independent native failures for the bounded byte transform.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum UiResourceDecodeError {
    EmptyInput,
    InputTooLarge { actual: usize, limit: usize },
    AllocationFailed,
}

/// Transform arbitrary bytes using caller-supplied fixed-size tables.
///
/// First construct `mask[i] = a[i] ^ b[i % 48]` for the 64-byte mask,
/// then return `encoded[j] ^ mask[j % 64]` for every input byte. In particular,
/// the B-table index wraps with `(j % 64) % 48`, not `j % 48`.
/// The borrowed input and tables remain unchanged; the result owns fresh bytes.
/// Empty or oversized input is rejected before reserving output memory, and
/// a failed reservation returns [`UiResourceDecodeError::AllocationFailed`].
pub fn decode_ui_resource_bytes(
    encoded: &[u8],
    a: &[u8; 64],
    b: &[u8; 48],
) -> Result<Vec<u8>, UiResourceDecodeError> {
    if encoded.is_empty() {
        return Err(UiResourceDecodeError::EmptyInput);
    }
    if encoded.len() > MAX_UI_RESOURCE_BYTES {
        return Err(UiResourceDecodeError::InputTooLarge {
            actual: encoded.len(),
            limit: MAX_UI_RESOURCE_BYTES,
        });
    }

    let mut output = Vec::new();
    output
        .try_reserve_exact(encoded.len())
        .map_err(|_| UiResourceDecodeError::AllocationFailed)?;

    let mut mask = [0_u8; 64];
    for (i, byte) in mask.iter_mut().enumerate() {
        *byte = a[i] ^ b[i % 48];
    }
    for (j, byte) in encoded.iter().enumerate() {
        output.push(byte ^ mask[j % 64]);
    }
    Ok(output)
}
