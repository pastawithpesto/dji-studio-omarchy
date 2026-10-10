//! Restricted ordered typed-value serialization, not a project parser or writer.
//!
//! Successful bytes use the original nle_core.dll 150b70/153190 rules and only
//! the proven 14e370 integral-real domain. CRC covers the returned data bytes
//! (131500), not an envelope. Source SHA256:
//! 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1.
//! See tests/fixtures/project_dom/README.md for approved contracts and limits.
//! Ownership, caps, error order and fallible allocation are native design.

use std::fmt;

pub const MAX_OUTPUT_BYTES: usize = 33_554_432;
pub const MAX_DEPTH: usize = 64;
pub const MAX_RECORDS: usize = 100_000;

/// Caller-owned values. Object order and existing duplicate keys are retained.
/// Safe `String` construction requires valid UTF-8. Raw fragments, precision
/// metadata and writer options cannot be represented by this type.
#[derive(Debug, PartialEq, Eq)]
pub enum DomValue {
    Null,
    Bool(bool),
    I64(i64),
    U64(u64),
    String(String),
    Array(Vec<DomValue>),
    Object(Vec<(String, DomValue)>),
    F64Bits(u64),
}

/// Root depth is zero. Every value and every object key counts one record.
/// Limits may be lowered to zero, but cannot exceed the public hard maxima.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DomLimits {
    pub max_output_bytes: usize,
    pub max_depth: usize,
    pub max_records: usize,
}

impl Default for DomLimits {
    fn default() -> Self {
        Self {
            max_output_bytes: MAX_OUTPUT_BYTES,
            max_depth: MAX_DEPTH,
            max_records: MAX_RECORDS,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LimitField {
    OutputBytes,
    Depth,
    Records,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DomError {
    InvalidLimits {
        field: LimitField,
        requested: usize,
        maximum: usize,
    },
    DepthLimit {
        limit: usize,
        attempted_depth: usize,
    },
    RecordLimit {
        limit: usize,
        attempted_records: usize,
    },
    OutputLimit {
        limit: usize,
        attempted_bytes: usize,
    },
    NonFiniteReal {
        bits: u64,
    },
    UnsupportedReal {
        bits: u64,
    },
    Allocation {
        requested_bytes: usize,
    },
    InternalLengthMismatch,
}

impl fmt::Display for DomError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidLimits {
                field,
                requested,
                maximum,
            } => write!(
                f,
                "{field:?} limit {requested} exceeds hard maximum {maximum}"
            ),
            Self::DepthLimit {
                limit,
                attempted_depth,
            } => write!(f, "value depth {attempted_depth} exceeds {limit}"),
            Self::RecordLimit {
                limit,
                attempted_records,
            } => write!(f, "record count {attempted_records} exceeds {limit}"),
            Self::OutputLimit {
                limit,
                attempted_bytes,
            } => write!(f, "output length {attempted_bytes} exceeds {limit}"),
            Self::NonFiniteReal { bits } => write!(f, "nonfinite real bits {bits:016x}"),
            Self::UnsupportedReal { bits } => write!(f, "unsupported real bits {bits:016x}"),
            Self::Allocation { requested_bytes } => {
                write!(f, "cannot reserve {requested_bytes} output bytes")
            }
            Self::InternalLengthMismatch => f.write_str("internal serialized length mismatch"),
        }
    }
}

impl std::error::Error for DomError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DomSignature {
    pub crc32: u32,
    pub lower_hex: [u8; 8],
}

/// Bytes and signature are separate; no signature or terminator is appended.
#[derive(Debug, PartialEq, Eq)]
pub struct SerializedDom {
    pub bytes: Vec<u8>,
    pub signature: DomSignature,
}

const fn crc_table() -> [u32; 256] {
    let mut table = [0; 256];
    let mut index = 0;
    while index < table.len() {
        let mut value = index as u32;
        let mut bit = 0;
        while bit < 8 {
            value = (value >> 1) ^ (0xedb8_8320 & 0u32.wrapping_sub(value & 1));
            bit += 1;
        }
        table[index] = value;
        index += 1;
    }
    table
}

const CRC_TABLE: [u32; 256] = crc_table();

/// Hash the complete borrowed span, including embedded NUL or invalid UTF-8.
/// This allocation-free operation does not apply serializer limits or parse.
pub fn signature(bytes: &[u8]) -> DomSignature {
    let mut crc = u32::MAX;
    for byte in bytes {
        crc = (crc >> 8) ^ CRC_TABLE[((crc ^ u32::from(*byte)) & 255) as usize];
    }
    crc = !crc;
    let mut hex = [0; 8];
    for (index, digit) in hex.iter_mut().enumerate() {
        *digit = b"0123456789abcdef"[((crc >> ((7 - index) * 4)) & 15) as usize];
    }
    DomSignature {
        crc32: crc,
        lower_hex: hex,
    }
}

fn validate_limits(limits: DomLimits) -> Result<(), DomError> {
    for (field, requested, maximum) in [
        (
            LimitField::OutputBytes,
            limits.max_output_bytes,
            MAX_OUTPUT_BYTES,
        ),
        (LimitField::Depth, limits.max_depth, MAX_DEPTH),
        (LimitField::Records, limits.max_records, MAX_RECORDS),
    ] {
        if requested > maximum {
            return Err(DomError::InvalidLimits {
                field,
                requested,
                maximum,
            });
        }
    }
    Ok(())
}

trait Sink {
    fn chunk(&mut self, bytes: &[u8]) -> Result<(), DomError>;
}

struct Counter {
    bytes: usize,
    maximum: usize,
}

impl Sink for Counter {
    fn chunk(&mut self, bytes: &[u8]) -> Result<(), DomError> {
        let attempted = self
            .bytes
            .checked_add(bytes.len())
            .ok_or(DomError::InternalLengthMismatch)?;
        if attempted > self.maximum {
            return Err(DomError::OutputLimit {
                limit: self.maximum,
                attempted_bytes: attempted,
            });
        }
        self.bytes = attempted;
        Ok(())
    }
}

struct Emitter {
    bytes: Vec<u8>,
    planned: usize,
}

impl Sink for Emitter {
    fn chunk(&mut self, bytes: &[u8]) -> Result<(), DomError> {
        let next = self
            .bytes
            .len()
            .checked_add(bytes.len())
            .ok_or(DomError::InternalLengthMismatch)?;
        if next > self.planned || next > self.bytes.capacity() {
            return Err(DomError::InternalLengthMismatch);
        }
        self.bytes.extend_from_slice(bytes);
        Ok(())
    }
}

struct Traversal {
    limits: DomLimits,
    records: usize,
}

impl Traversal {
    fn record(&mut self) -> Result<(), DomError> {
        let attempted = self
            .records
            .checked_add(1)
            .ok_or(DomError::InternalLengthMismatch)?;
        if attempted > self.limits.max_records {
            return Err(DomError::RecordLimit {
                limit: self.limits.max_records,
                attempted_records: attempted,
            });
        }
        self.records = attempted;
        Ok(())
    }

    fn value<S: Sink>(
        &mut self,
        value: &DomValue,
        depth: usize,
        sink: &mut S,
    ) -> Result<(), DomError> {
        if depth > self.limits.max_depth {
            return Err(DomError::DepthLimit {
                limit: self.limits.max_depth,
                attempted_depth: depth,
            });
        }
        self.record()?;
        match value {
            DomValue::Null => sink.chunk(b"null"),
            DomValue::Bool(value) => sink.chunk(if *value { b"true" } else { b"false" }),
            DomValue::I64(value) => number(*value < 0, value.unsigned_abs(), false, sink),
            DomValue::U64(value) => number(false, *value, false, sink),
            DomValue::String(value) => quoted(value, sink),
            DomValue::F64Bits(bits) => {
                let (negative, magnitude) = integral_real(*bits)?;
                number(negative, magnitude, true, sink)
            }
            DomValue::Array(values) => {
                sink.chunk(b"[")?;
                for (index, child) in values.iter().enumerate() {
                    if index != 0 {
                        sink.chunk(b",")?;
                    }
                    self.value(child, child_depth(depth)?, sink)?;
                }
                sink.chunk(b"]")
            }
            DomValue::Object(values) => {
                sink.chunk(b"{")?;
                for (index, (key, child)) in values.iter().enumerate() {
                    if index != 0 {
                        sink.chunk(b",")?;
                    }
                    self.record()?;
                    quoted(key, sink)?;
                    sink.chunk(b":")?;
                    self.value(child, child_depth(depth)?, sink)?;
                }
                sink.chunk(b"}")
            }
        }
    }
}

fn child_depth(parent: usize) -> Result<usize, DomError> {
    parent
        .checked_add(1)
        .ok_or(DomError::InternalLengthMismatch)
}

fn integral_real(bits: u64) -> Result<(bool, u64), DomError> {
    let exponent = (bits >> 52) & 0x7ff;
    if exponent == 0x7ff {
        return Err(DomError::NonFiniteReal { bits });
    }
    let negative = bits >> 63 != 0;
    if bits & 0x7fff_ffff_ffff_ffff == 0 {
        return Ok((negative, 0));
    }
    if !(1023..=1075).contains(&exponent) {
        return Err(DomError::UnsupportedReal { bits });
    }
    let shift = 1075 - exponent;
    let significand = (bits & 0x000f_ffff_ffff_ffff) | (1u64 << 52);
    if significand & ((1u64 << shift) - 1) != 0 {
        return Err(DomError::UnsupportedReal { bits });
    }
    Ok((negative, significand >> shift))
}

fn number<S: Sink>(
    negative: bool,
    mut magnitude: u64,
    real: bool,
    sink: &mut S,
) -> Result<(), DomError> {
    let mut digits = [0; 22];
    let mut start = digits.len();
    if real {
        start -= 2;
        digits[start..].copy_from_slice(b".0");
    }
    loop {
        start -= 1;
        digits[start] = b'0' + (magnitude % 10) as u8;
        magnitude /= 10;
        if magnitude == 0 {
            break;
        }
    }
    if negative {
        start -= 1;
        digits[start] = b'-';
    }
    sink.chunk(&digits[start..])
}

fn quoted<S: Sink>(value: &str, sink: &mut S) -> Result<(), DomError> {
    sink.chunk(b"\"")?;
    for byte in value.bytes() {
        match byte {
            b'"' => sink.chunk(b"\\\"")?,
            b'\\' => sink.chunk(b"\\\\")?,
            8 => sink.chunk(b"\\b")?,
            9 => sink.chunk(b"\\t")?,
            10 => sink.chunk(b"\\n")?,
            12 => sink.chunk(b"\\f")?,
            13 => sink.chunk(b"\\r")?,
            0..=31 => {
                let escape = [
                    b'\\',
                    b'u',
                    b'0',
                    b'0',
                    b"0123456789ABCDEF"[(byte >> 4) as usize],
                    b"0123456789ABCDEF"[(byte & 15) as usize],
                ];
                sink.chunk(&escape)?;
            }
            _ => sink.chunk(&[byte])?,
        }
    }
    sink.chunk(b"\"")
}

/// Serialize only the restricted approved domain. Complete preflight precedes
/// the sole fallible reserve. Every error retains input and returns no output.
pub fn serialize(value: &DomValue, limits: DomLimits) -> Result<SerializedDom, DomError> {
    serialize_with_reserve(value, limits, |bytes, length| {
        bytes.try_reserve_exact(length).map_err(|_| ())
    })
}

// The private reservation boundary lets unit tests deny allocation. Production
// supplies only Vec::try_reserve_exact; there is no public injection/switch.
fn serialize_with_reserve(
    value: &DomValue,
    limits: DomLimits,
    reserve: impl FnOnce(&mut Vec<u8>, usize) -> Result<(), ()>,
) -> Result<SerializedDom, DomError> {
    validate_limits(limits)?;
    let mut counter = Counter {
        bytes: 0,
        maximum: limits.max_output_bytes,
    };
    Traversal { limits, records: 0 }.value(value, 0, &mut counter)?;
    let mut emitter = Emitter {
        bytes: Vec::new(),
        planned: counter.bytes,
    };
    reserve(&mut emitter.bytes, emitter.planned).map_err(|()| DomError::Allocation {
        requested_bytes: emitter.planned,
    })?;
    Traversal { limits, records: 0 }.value(value, 0, &mut emitter)?;
    if emitter.bytes.len() != emitter.planned {
        return Err(DomError::InternalLengthMismatch);
    }
    let signature = signature(&emitter.bytes);
    Ok(SerializedDom {
        bytes: emitter.bytes,
        signature,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    #[test]
    fn reservation_refusal_preserves_input_and_occurs_after_preflight() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../tests/fixtures/project_dom/fault-fixtures.json"
        ))
        .unwrap();
        for case in fixture["cases"].as_array().unwrap() {
            if case.get("input").is_none() {
                continue;
            }
            let input = &case["input"];
            let value = match input["kind"].as_str().unwrap() {
                "Null" => DomValue::Null,
                "String" => DomValue::String(input["value"].as_str().unwrap().to_owned()),
                "F64Bits" => DomValue::F64Bits(
                    u64::from_str_radix(input["hex"].as_str().unwrap(), 16).unwrap(),
                ),
                kind => panic!("unexpected fixture kind {kind}"),
            };
            let before = format!("{value:?}");
            let mut limits = DomLimits::default();
            if let Some(output) = case["limits_override"]["max_output_bytes"].as_u64() {
                limits.max_output_bytes = output as usize;
            }
            let calls = Cell::new(0);
            let result = serialize_with_reserve(&value, limits, |_, _| {
                calls.set(calls.get() + 1);
                Err(())
            });
            let expected = &case["expected"];
            let error = match expected["kind"].as_str().unwrap() {
                "Allocation" => DomError::Allocation {
                    requested_bytes: expected["requested_bytes"].as_u64().unwrap() as usize,
                },
                "UnsupportedReal" => DomError::UnsupportedReal {
                    bits: u64::from_str_radix(expected["bits"].as_str().unwrap(), 16).unwrap(),
                },
                "OutputLimit" => DomError::OutputLimit {
                    limit: expected["limit"].as_u64().unwrap() as usize,
                    attempted_bytes: expected["attempted_bytes"].as_u64().unwrap() as usize,
                },
                kind => panic!("unexpected error {kind}"),
            };
            assert_eq!(result, Err(error), "{}", case["id"]);
            assert_eq!(calls.get(), case["reserve_calls"].as_u64().unwrap());
            assert_eq!(format!("{value:?}"), before);
        }
    }

    #[test]
    fn checked_append_rejects_overrun_without_growing_buffer() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../tests/fixtures/project_dom/fault-fixtures.json"
        ))
        .unwrap();
        let case = fixture["cases"]
            .as_array()
            .unwrap()
            .iter()
            .find(|case| case.get("private_append").is_some())
            .unwrap();
        let args = &case["private_append"];
        let mut emitter = Emitter {
            bytes: Vec::new(),
            planned: args["planned_length"].as_u64().unwrap() as usize,
        };
        emitter
            .bytes
            .try_reserve_exact(args["capacity_at_least"].as_u64().unwrap() as usize)
            .unwrap();
        let capacity = emitter.bytes.capacity();
        assert_eq!(
            emitter.chunk(b"null"),
            Err(DomError::InternalLengthMismatch)
        );
        assert!(emitter.bytes.is_empty());
        assert_eq!(emitter.bytes.capacity(), capacity);
        // A separately forced reserve success without actual capacity must
        // also fail before append; production never supplies this allocator.
        assert_eq!(
            serialize_with_reserve(&DomValue::Null, DomLimits::default(), |_, _| Ok(())),
            Err(DomError::InternalLengthMismatch)
        );
    }
}
