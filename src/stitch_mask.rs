//! Checked decoder for the supported Vince v2 `panomask` resource format.
//!
//! The malformed-input and allocation behavior is an independent native policy.
//! It does not reproduce the vendor decoder's unchecked writes.

const MAGIC: &[u8; 8] = b"panomask";
const HEADER_BYTES: usize = 20;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MaskLimits {
    /// Maximum number of decoded bytes accepted by this call.
    pub max_decoded_bytes: usize,
}

#[derive(Debug, PartialEq, Eq)]
pub struct DecodedMask {
    pub width: u32,
    pub height: u32,
    /// Pixels in the decoded linear order. Row orientation is not established.
    pub bytes: Vec<u8>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MaskError {
    pub kind: MaskErrorKind,
    /// Byte offset of the failing field, or the first trailing byte.
    pub offset: usize,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MaskErrorKind {
    Truncated,
    BadMagic,
    UnsupportedVersion,
    InvalidDimensions,
    SizeOverflow,
    AllocationLimit,
    NegativeRun,
    RunOverflow,
    ExtentMismatch,
    TrailingData,
    AllocationFailed,
}

#[derive(Clone, Copy)]
struct Header {
    width: u32,
    height: u32,
    extent: usize,
}

/// Decode one complete v2 mask resource.
///
/// This function accepts only exact magic plus version 2. It does not implement
/// version 0/1 or the vendor's magic-mismatch raw fallback.
pub fn decode_mask_v2(input: &[u8], limits: MaskLimits) -> Result<DecodedMask, MaskError> {
    let (header, terminator_end) = preflight(input, limits)?;
    let mut bytes = Vec::new();
    bytes
        .try_reserve_exact(header.extent)
        .map_err(|_| error(MaskErrorKind::AllocationFailed, 12))?;
    bytes.resize(header.extent, 0);

    let mut cursor = HEADER_BYTES;
    let mut written = 0_usize;
    loop {
        let count_offset = cursor;
        let count = read_i32(input, count_offset)?;
        cursor = cursor
            .checked_add(4)
            .ok_or_else(|| error(MaskErrorKind::Truncated, count_offset))?;
        if count == 0 {
            break;
        }
        let value = *input
            .get(cursor)
            .ok_or_else(|| error(MaskErrorKind::Truncated, cursor))?;
        cursor = cursor
            .checked_add(1)
            .ok_or_else(|| error(MaskErrorKind::Truncated, cursor))?;
        let count =
            usize::try_from(count).map_err(|_| error(MaskErrorKind::RunOverflow, count_offset))?;
        let end = written
            .checked_add(count)
            .ok_or_else(|| error(MaskErrorKind::RunOverflow, count_offset))?;
        let destination = bytes
            .get_mut(written..end)
            .ok_or_else(|| error(MaskErrorKind::RunOverflow, count_offset))?;
        destination.fill(value);
        written = end;
    }

    debug_assert_eq!(cursor, terminator_end);
    debug_assert_eq!(written, header.extent);
    Ok(DecodedMask {
        width: header.width,
        height: header.height,
        bytes,
    })
}

fn preflight(input: &[u8], limits: MaskLimits) -> Result<(Header, usize), MaskError> {
    if input.len() < MAGIC.len() {
        return Err(error(MaskErrorKind::Truncated, 0));
    }
    if &input[..MAGIC.len()] != MAGIC {
        return Err(error(MaskErrorKind::BadMagic, 0));
    }

    let version = read_i32(input, 8)?;
    if version != 2 {
        return Err(error(MaskErrorKind::UnsupportedVersion, 8));
    }

    let width_i32 = read_i32(input, 12)?;
    let height_i32 = read_i32(input, 16)?;
    if width_i32 <= 0 {
        return Err(error(MaskErrorKind::InvalidDimensions, 12));
    }
    if height_i32 <= 0 {
        return Err(error(MaskErrorKind::InvalidDimensions, 16));
    }

    let width = usize::try_from(width_i32).map_err(|_| error(MaskErrorKind::SizeOverflow, 12))?;
    let height = usize::try_from(height_i32).map_err(|_| error(MaskErrorKind::SizeOverflow, 12))?;
    let extent = width
        .checked_mul(height)
        .ok_or_else(|| error(MaskErrorKind::SizeOverflow, 12))?;
    if extent > limits.max_decoded_bytes {
        return Err(error(MaskErrorKind::AllocationLimit, 12));
    }

    let header = Header {
        width: width_i32 as u32,
        height: height_i32 as u32,
        extent,
    };
    let mut cursor = HEADER_BYTES;
    let mut decoded = 0_usize;

    loop {
        let count_offset = cursor;
        let count = read_i32(input, count_offset)?;
        cursor += 4;

        if count < 0 {
            return Err(error(MaskErrorKind::NegativeRun, count_offset));
        }
        if count == 0 {
            if decoded != extent {
                return Err(error(MaskErrorKind::ExtentMismatch, count_offset));
            }
            if cursor != input.len() {
                return Err(error(MaskErrorKind::TrailingData, cursor));
            }
            return Ok((header, cursor));
        }

        let value_offset = cursor;
        if input.get(value_offset).is_none() {
            return Err(error(MaskErrorKind::Truncated, value_offset));
        }
        cursor += 1;

        let run =
            usize::try_from(count).map_err(|_| error(MaskErrorKind::RunOverflow, count_offset))?;
        let remaining = extent - decoded;
        if run > remaining {
            return Err(error(MaskErrorKind::RunOverflow, count_offset));
        }
        decoded += run;
    }
}

fn read_i32(input: &[u8], offset: usize) -> Result<i32, MaskError> {
    let end = offset
        .checked_add(4)
        .ok_or_else(|| error(MaskErrorKind::Truncated, offset))?;
    let field = input
        .get(offset..end)
        .ok_or_else(|| error(MaskErrorKind::Truncated, offset))?;
    let bytes: [u8; 4] = field
        .try_into()
        .map_err(|_| error(MaskErrorKind::Truncated, offset))?;
    Ok(i32::from_le_bytes(bytes))
}

fn error(kind: MaskErrorKind, offset: usize) -> MaskError {
    MaskError { kind, offset }
}
