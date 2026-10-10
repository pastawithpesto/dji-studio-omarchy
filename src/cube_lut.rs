//! Independent, bounded reader for an ordered subset of `.cube` text resources.
//!
//! Source observations: Windows 1.0.0.30839 original edge33 resource SHA-256
//! b18162854ab47702068410c33afa98a8cb6eef159fc5a04ce0e65fad0fd8947e,
//! and edge65 resource fa6537da3235c281da6e361806d3e9ee93f5532ad95471878c5d6c05157caa9c.
//! Both contain comments, one LUT_3D_SIZE record and exactly edge^3 finite triples.
//! The independently reviewed contract is CUBE-SYNTAX-CONTRACT.md SHA-256
//! 8060eb6a4992504db52d150ee18cec3da51246f29fd1ecdc2c729bcc9a04bfa9,
//! in sol-calibration-review/swarm-20261010-2154 (Astra310, root315).
//!
//! Binary64 storage, limits, grammar extensions and errors are independent design.
//! Rows/components retain text order; no table-axis/color interpretation, vendor
//! loader, interpolation, clamping, blend, GPU upload or Windows parity is known.

use std::fmt;

/// Caller-chosen resource bounds, with no inferred vendor defaults.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CubeLimits {
    pub max_bytes: usize,
    pub max_rows: usize,
}

/// An owned numeric table, with exactly `edge()^3` rows in source order.
#[derive(Debug, Clone, PartialEq)]
pub struct CubeTable {
    edge: usize,
    rows: Vec<[f64; 3]>,
}

impl CubeTable {
    pub const fn edge(&self) -> usize {
        self.edge
    }

    /// Each component retains its position in the input triple.
    pub fn rows(&self) -> &[[f64; 3]] {
        &self.rows
    }
}

/// Independent parser errors; these are not recovered DJI status codes.
///
/// Line numbers are one-based physical lines. No source text is retained.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CubeParseError {
    InputTooLarge {
        actual: usize,
        limit: usize,
    },
    InvalidUtf8,
    MissingSize,
    InvalidSize {
        line: usize,
    },
    DuplicateSize {
        line: usize,
    },
    DataBeforeSize {
        line: usize,
    },
    SizeOverflow {
        line: usize,
    },
    RowLimitExceeded {
        line: usize,
        required: usize,
        limit: usize,
    },
    InvalidData {
        line: usize,
    },
    RowCountMismatch {
        expected: usize,
        actual: usize,
        line: Option<usize>,
    },
    AllocationFailed,
}

impl fmt::Display for CubeParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "cube subset parse error: {self:?}")
    }
}

impl std::error::Error for CubeParseError {}

/// Parse one `LUT_3D_SIZE` declaration followed by exactly edge^3 finite triples.
///
/// Byte limit and strict UTF-8 precede line validation. Blank lines and whole-line
/// `#` comments are skipped; noncomment syntax uses only ASCII space/tab. CR is
/// stripped only immediately before an actual LF. Unknown directives and inline
/// comments fail. The caller supplies both limits; input is never modified.
///
/// Header arithmetic/row-limit checks precede fallible row reservation. Triples
/// are validated before detecting a first extra row. A duplicate size declaration
/// takes precedence over its token validation. Successful output owns its values.
pub fn parse_cube_subset(input: &[u8], limits: CubeLimits) -> Result<CubeTable, CubeParseError> {
    if input.len() > limits.max_bytes {
        return Err(CubeParseError::InputTooLarge {
            actual: input.len(),
            limit: limits.max_bytes,
        });
    }
    let text = std::str::from_utf8(input).map_err(|_| CubeParseError::InvalidUtf8)?;
    let mut declaration = None;
    let mut rows: Vec<[f64; 3]> = Vec::new();

    for (index, physical) in text.split_inclusive('\n').enumerate() {
        let line = index + 1;
        let record = if let Some(terminated) = physical.strip_suffix('\n') {
            terminated.strip_suffix('\r').unwrap_or(terminated)
        } else {
            physical
        };
        let record = record.trim_matches([' ', '\t']);
        if record.is_empty() || record.starts_with('#') {
            continue;
        }
        if !record
            .bytes()
            .all(|byte| byte.is_ascii_graphic() || byte == b' ' || byte == b'\t')
        {
            return Err(CubeParseError::InvalidData { line });
        }
        let mut tokens = record.split([' ', '\t']).filter(|token| !token.is_empty());
        let first = tokens.next().ok_or(CubeParseError::InvalidData { line })?;
        if first == "LUT_3D_SIZE" {
            if declaration.is_some() {
                return Err(CubeParseError::DuplicateSize { line });
            }
            let token = tokens.next().ok_or(CubeParseError::InvalidSize { line })?;
            if tokens.next().is_some()
                || token.is_empty()
                || !token.bytes().all(|byte| byte.is_ascii_digit())
            {
                return Err(CubeParseError::InvalidSize { line });
            }
            let edge = token
                .parse::<usize>()
                .ok()
                .filter(|&edge| edge > 0)
                .ok_or(CubeParseError::InvalidSize { line })?;
            let required = edge
                .checked_mul(edge)
                .and_then(|square| square.checked_mul(edge))
                .ok_or(CubeParseError::SizeOverflow { line })?;
            required
                .checked_mul(std::mem::size_of::<[f64; 3]>())
                .filter(|&bytes| bytes <= isize::MAX as usize)
                .ok_or(CubeParseError::SizeOverflow { line })?;
            if required > limits.max_rows {
                return Err(CubeParseError::RowLimitExceeded {
                    line,
                    required,
                    limit: limits.max_rows,
                });
            }
            rows.try_reserve_exact(required)
                .map_err(|_| CubeParseError::AllocationFailed)?;
            declaration = Some((edge, required));
        } else {
            let second = tokens.next().ok_or(CubeParseError::InvalidData { line })?;
            let third = tokens.next().ok_or(CubeParseError::InvalidData { line })?;
            if tokens.next().is_some() {
                return Err(CubeParseError::InvalidData { line });
            }
            let values = [first, second, third].map(parse_number);
            let [Some(a), Some(b), Some(c)] = values else {
                return Err(CubeParseError::InvalidData { line });
            };
            let (_, required) = declaration.ok_or(CubeParseError::DataBeforeSize { line })?;
            if rows.len() == required {
                // Checked allocation bounds above guarantee required + 1 fits.
                return Err(CubeParseError::RowCountMismatch {
                    expected: required,
                    actual: required + 1,
                    line: Some(line),
                });
            }
            rows.push([a, b, c]);
        }
    }

    let (edge, required) = declaration.ok_or(CubeParseError::MissingSize)?;
    if rows.len() != required {
        return Err(CubeParseError::RowCountMismatch {
            expected: required,
            actual: rows.len(),
            line: None,
        });
    }
    Ok(CubeTable { edge, rows })
}

/// ASCII decimal grammar, separately checked before finite binary64 conversion.
fn parse_number(token: &str) -> Option<f64> {
    let bytes = token.as_bytes();
    let mut at = 0;
    if matches!(bytes.first(), Some(b'+' | b'-')) {
        at += 1;
    }
    let mut digits = 0usize;
    while bytes.get(at).is_some_and(u8::is_ascii_digit) {
        at += 1;
        digits += 1;
    }
    if bytes.get(at) == Some(&b'.') {
        at += 1;
        while bytes.get(at).is_some_and(u8::is_ascii_digit) {
            at += 1;
            digits += 1;
        }
    }
    if digits == 0 {
        return None;
    }
    if matches!(bytes.get(at), Some(b'e' | b'E')) {
        at += 1;
        if matches!(bytes.get(at), Some(b'+' | b'-')) {
            at += 1;
        }
        let exponent_start = at;
        while bytes.get(at).is_some_and(u8::is_ascii_digit) {
            at += 1;
        }
        if at == exponent_start {
            return None;
        }
    }
    if at != bytes.len() {
        return None;
    }
    token.parse::<f64>().ok().filter(|value| value.is_finite())
}
