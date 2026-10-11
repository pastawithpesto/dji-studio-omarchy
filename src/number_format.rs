//! Experimental isolated finite binary64 logical formatter; not wired into DOM.
//!
//! Source: nle_core.dll 1.0.0.30839, SHA256
//! 3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1,
//! 0x18014e370..0x18014f970. Contracts: number-format-contract/R1 (review703),
//! float-normal-core/WORD-CONTRACT.md and INTEGER-BRANCHES.md (review727).
//! Full artifact/REA/table pins live in tests/fixtures/number_format/provenance.json.
//! The 64-byte checked scratch and errors are independent native policy. Reviewed
//! <=25 bounds only the initialized logical result, not vendor scratch or ABI.
//! No universal shortest theorem, vendor execution or Windows parity is claimed.
#![forbid(unsafe_code)]

#[path = "number_format_tables.rs"]
mod tables;
use tables::{CACHE, PAIRS, TRIM};

/// Independent API cap, not a vendor allocation requirement.
pub const HARD_MAX_OUTPUT_BYTES: usize = 64;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum InvariantStage {
    CacheIndex,
    Coefficient,
    DigitRange,
    Span,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum NumberError {
    InvalidLimit { provided: usize, maximum: usize },
    NonFinite { bits: u64 },
    InvariantViolation { stage: InvariantStage },
    OutputLimit { limit: usize, required: usize },
    BufferTooSmall { available: usize, required: usize },
}

impl std::fmt::Display for NumberError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Formatting directly into the caller's sink has no internal allocation.
        match self {
            Self::InvalidLimit { provided, maximum } => {
                write!(f, "invalid limit {provided}; maximum {maximum}")
            }
            Self::NonFinite { bits } => write!(f, "nonfinite binary64 bits {bits:016x}"),
            Self::InvariantViolation { stage } => write!(f, "formatter invariant: {stage:?}"),
            Self::OutputLimit { limit, required } => {
                write!(f, "output requires {required} bytes; limit {limit}")
            }
            Self::BufferTooSmall {
                available,
                required,
            } => write!(f, "output requires {required} bytes; available {available}"),
        }
    }
}
impl std::error::Error for NumberError {}
type Checked<T> = Result<T, NumberError>;
fn fault(stage: InvariantStage) -> NumberError {
    NumberError::InvariantViolation { stage }
}

/// Format exact borrowed IEEE754 bits into only the successful returned prefix.
///
/// No heap allocation or floating-point operation. Every error preserves input
/// and the entire destination; success preserves all bytes after the prefix.
/// Order: invalid limit, nonfinite, internal invariants, output limit, capacity.
pub fn format_finite_bits<'a>(
    bits: &u64,
    destination: &'a mut [u8],
    max_output_bytes: usize,
) -> Checked<&'a [u8]> {
    if max_output_bytes > HARD_MAX_OUTPUT_BYTES {
        return Err(NumberError::InvalidLimit {
            provided: max_output_bytes,
            maximum: HARD_MAX_OUTPUT_BYTES,
        });
    }
    let copied = *bits;
    if (copied >> 52) & 0x7ff == 0x7ff {
        return Err(NumberError::NonFinite { bits: copied });
    }
    let mut scratch = Scratch([b'0'; HARD_MAX_OUTPUT_BYTES]);
    let required = emit(copied, &mut scratch)?;
    // G3 logical bound; never a fallback/truncation or caller scratch guarantee.
    if required > 25 {
        return Err(fault(InvariantStage::Span));
    }
    if required > max_output_bytes {
        return Err(NumberError::OutputLimit {
            limit: max_output_bytes,
            required,
        });
    }
    if required > destination.len() {
        return Err(NumberError::BufferTooSmall {
            available: destination.len(),
            required,
        });
    }
    destination[..required].copy_from_slice(&scratch.0[..required]);
    Ok(&destination[..required])
}

struct Scratch([u8; HARD_MAX_OUTPUT_BYTES]);
impl Scratch {
    fn put(&mut self, at: usize, bytes: &[u8]) -> Checked<usize> {
        let end = at
            .checked_add(bytes.len())
            .ok_or(fault(InvariantStage::Span))?;
        self.0
            .get_mut(at..end)
            .ok_or(fault(InvariantStage::Span))?
            .copy_from_slice(bytes);
        Ok(end)
    }
    fn byte(&mut self, at: usize, byte: u8) -> Checked<usize> {
        self.put(at, &[byte])
    }
    fn get(&self, at: usize) -> Checked<u8> {
        self.0.get(at).copied().ok_or(fault(InvariantStage::Span))
    }
    fn pair(&mut self, at: usize, value: u64, leading: bool) -> Checked<usize> {
        if value >= 100 {
            return Err(fault(InvariantStage::DigitRange));
        }
        let skip = usize::from(leading && value < 10);
        let start = value as usize * 2;
        let bytes = PAIRS
            .get(start + skip..start + 2)
            .ok_or(fault(InvariantStage::DigitRange))?;
        self.put(at, bytes)
    }
}

// Signed32 IMUL/SAR domains proven in WORD-CONTRACT; checked against corruption.
fn selector(e: i32, asym: i32) -> Checked<(i32, i32)> {
    let q = e
        .checked_mul(0x4d105)
        .and_then(|x| x.checked_sub(asym * 0x200a5))
        .ok_or(fault(InvariantStage::Coefficient))?
        >> 20;
    let d = q
        .checked_mul(-0x3526b)
        .ok_or(fault(InvariantStage::Coefficient))?
        >> 16;
    Ok((q, d))
}
fn cache(q: i32) -> Checked<(u64, u64)> {
    let i = 343i32
        .checked_sub(q)
        .and_then(|x| usize::try_from(x).ok())
        .ok_or(fault(InvariantStage::CacheIndex))?;
    CACHE
        .get(i)
        .copied()
        .ok_or(fault(InvariantStage::CacheIndex))
}
fn shl(word: u64, count: i32) -> u64 {
    word.wrapping_shl((count as u32) & 63)
}
fn shr(word: u64, count: i32) -> u64 {
    word.wrapping_shr((count as u32) & 63)
}

// 14e8ae..14e8df/interval: two MULs and modulo low sum; ONE carry by OR.
fn product(x: u64, h: u64, l: u64) -> (u64, u64) {
    let a = ((u128::from(x) * u128::from(l)) >> 64) as u64;
    let second = u128::from(x) * u128::from(h);
    let c = second as u64;
    let low = c.wrapping_add(a);
    let carry = u64::from(low < c || low < a);
    (((second >> 64) as u64).wrapping_add(carry), low)
}
fn div10(n: u64) -> u64 {
    ((u128::from(n) * 0xcccccccccccccccd) >> 67) as u64
}
fn fast(h: u64, l: u64, bound: u64) -> Option<u64> {
    let r = h - 10 * div10(h);
    let probe = (r << 60) | (l >> 4);
    let total = bound.wrapping_add(probe);
    const U: u64 = 0xa000000000000000;
    if l == 1 << 63 || bound == probe || U.wrapping_sub(total) <= 1 {
        return None;
    }
    let coarse = total >= U;
    Some(if probe <= bound || coarse {
        h - r + if coarse { 10 } else { 0 }
    } else {
        h + u64::from(l >= 1 << 63)
    })
}
fn interval(sig: u64, shift: i32, h: u64, old_l: u64, asym: i32) -> Checked<u64> {
    // Original INC changes only L. All pinned rows prove old_l != MAX.
    let l = old_l
        .checked_add(1)
        .ok_or(fault(InvariantStage::Coefficient))?;
    let (lh, ll) = product(shl(4 * sig - 2 + asym as u64, shift), h, l);
    let (mh, ml) = product(shl(4 * sig, shift), h, l);
    let (rh, rl) = product(shl(4 * sig + 2, shift), h, l);
    let lower = (lh | u64::from(ll > 1)) + (sig & 1);
    let center = mh | u64::from(ml > 1);
    let upper = (rh | u64::from(rl > 1))
        .checked_sub(sig & 1)
        .ok_or(fault(InvariantStage::Coefficient))?;
    let c = center >> 2;
    let d = div10(c);
    let v = 40 * d;
    let lc = lower <= v;
    let rc = v + 40 <= upper;
    if c >= 10 && lc != rc {
        return Ok(10 * d + if rc { 10 } else { 0 });
    }
    let v = 4 * c;
    let left = lower <= v;
    let right = v + 4 <= upper;
    let near = center > v + 2 || (center == v + 2 && c & 1 != 0);
    Ok(c + u64::from(if left == right { near } else { right }))
}

#[derive(Clone, Copy)]
enum Kind {
    Integral,
    Normal,
    Subnormal,
}
fn coefficient(exponent: u32, fraction: u64) -> Checked<(u64, i32, Kind)> {
    if exponent == 0 {
        // 14f105..14f1f8. All four exact modular fallback windows are empty
        // for 1..2^52-1 (646/659, original predicates independently closed727).
        let (h, l) = product(fraction * 8, 0x9e19db92b4e31ba9, 0x6c07a2c26a8346d1);
        let c = fast(h, l, 0x278676e4ad38c6ea).ok_or(fault(InvariantStage::Coefficient))?;
        if c == 0 || c >= 100_000_000_000_000_000 {
            return Err(fault(InvariantStage::Coefficient));
        }
        return Ok((c, -324, Kind::Subnormal));
    }
    let sig = fraction | (1 << 52);
    let e = exponent as i32 - 1075;
    if (-52..=0).contains(&e) && sig.trailing_zeros() >= (-e) as u32 {
        return Ok((shr(sig, -e), 0, Kind::Integral));
    }
    if fraction != 0 {
        let (q, d) = selector(e, 0)?;
        let beta = e + d;
        if !(0..=3).contains(&beta) {
            return Err(fault(InvariantStage::Coefficient));
        }
        let (h, l) = cache(q)?;
        let (high, low) = product(shl(sig, beta + 1), h, l);
        if let Some(c) = fast(high, low, shr(h, 4 - beta)) {
            return checked_normal(c, q);
        }
    }
    let asym = i32::from(fraction == 0 && exponent >= 2);
    let (q, d) = selector(e, asym)?;
    let shift = e + 1 + d;
    if !(1..=4).contains(&shift) {
        return Err(fault(InvariantStage::Coefficient));
    }
    let (h, l) = cache(q)?;
    checked_normal(interval(sig, shift, h, l, asym)?, q)
}
fn checked_normal(c: u64, q: i32) -> Checked<(u64, i32, Kind)> {
    if !(1_000_000_000_000_000..100_000_000_000_000_000).contains(&c) || !(-324..=292).contains(&q)
    {
        return Err(fault(InvariantStage::Coefficient));
    }
    Ok((c, q, Kind::Normal))
}

// G2 reciprocal inequalities cover these exact source domains; products fit128.
fn split8(n: u64) -> (u64, u64) {
    let high = ((u128::from(n) * 0xabcc77118461cefd) >> 90) as u64;
    // Original SUB32: actual residue <1e8, so this reduction preserves it.
    let low = (n as u32).wrapping_sub((high * 100_000_000) as u32);
    (high, u64::from(low))
}
fn fixed4(b: &mut Scratch, at: usize, n: u64) -> Checked<usize> {
    if n >= 10000 {
        return Err(fault(InvariantStage::DigitRange));
    }
    let h = (n * 0x147b) >> 19;
    let end = b.pair(at, h, false)?;
    b.pair(end, n - h * 100, false)
}
fn fixed8(b: &mut Scratch, at: usize, n: u64) -> Checked<usize> {
    if n >= 100_000_000 {
        return Err(fault(InvariantStage::DigitRange));
    }
    let h = (n * 0x68db8bb) >> 40;
    let end = fixed4(b, at, h)?;
    fixed4(b, end, n - h * 10000)
}
fn under8(b: &mut Scratch, at: usize, n: u64) -> Checked<usize> {
    if n == 0 || n >= 100_000_000 {
        return Err(fault(InvariantStage::DigitRange));
    }
    if n < 100 {
        return b.pair(at, n, true);
    }
    if n < 10000 {
        let h = (n * 0x147b) >> 19;
        let end = b.pair(at, h, true)?;
        return b.pair(end, n - h * 100, false);
    }
    if n < 1_000_000 {
        let h = (n * 0x68db9) >> 32;
        let end = b.pair(at, h, true)?;
        return fixed4(b, end, n - h * 10000);
    }
    let h = (n * 0x68db8bb) >> 40;
    let prefix = (h * 0x147b) >> 19;
    let end = b.pair(at, prefix, true)?;
    let end = b.pair(end, h - prefix * 100, false)?;
    fixed4(b, end, n - h * 10000)
}
fn integer(b: &mut Scratch, at: usize, n: u64, subnormal: bool) -> Checked<usize> {
    if n == 0 || n >= 100_000_000_000_000_000 {
        return Err(fault(InvariantStage::DigitRange));
    }
    if subnormal && n >= 1_000_000_000_000_000 {
        let (high, low) = split8(n);
        let (top, middle) = split8(high);
        let end = if top == 0 {
            at
        } else {
            b.byte(at, b'0' + top as u8)?
        };
        let end = fixed8(b, end, middle)?;
        return fixed8(b, end, low);
    }
    if n < 100_000_000 {
        return under8(b, at, n);
    }
    let (high, low) = split8(n);
    let end = under8(b, at, high)?;
    fixed8(b, end, low)
}
fn trim(n: u64) -> Checked<usize> {
    TRIM.get(n as usize)
        .copied()
        .map(usize::from)
        .ok_or(fault(InvariantStage::DigitRange))
}
fn common(b: &mut Scratch, at: usize, c: u64) -> Checked<usize> {
    if !(1_000_000_000_000_000..100_000_000_000_000_000).contains(&c) {
        return Err(fault(InvariantStage::DigitRange));
    }
    let (high, low) = split8(c);
    let top = (high * 0xd1b71759) >> 45;
    let rem = high - top * 10000;
    let hundred = (top * 0x28f5d) >> 24;
    let lead = (hundred * 0x29) >> 12;
    let x = hundred - lead * 100;
    let y = top - hundred * 100;
    b.byte(at, b'0' + lead as u8)?;
    let p = at + usize::from(lead != 0);
    b.pair(p, x, false)?;
    b.pair(p + 2, y, false)?;
    let bh = (rem * 0x147b) >> 19;
    let lh = (low * 0x68db8bb) >> 40;
    let r = low - lh * 10000;
    let lhh = (lh * 0x147b) >> 19;
    let rh = (r * 0x147b) >> 19;
    let bz = rem - bh * 100;
    let lz = lh - lhh * 100;
    let rz = r - rh * 100;
    b.pair(p + 4, bh, false)?;
    b.pair(p + 6, bz, false)?;
    b.pair(p + 8, lhh, false)?;
    b.pair(p + 10, lz, false)?;
    b.pair(p + 12, rh, false)?;
    b.pair(p + 14, rz, false)?;
    // Exact eight source trim branches, flags normalized under G2 proof.
    let end = if low != 0 {
        if r != 0 {
            p + 16 - if rz != 0 { trim(rz)? } else { 2 + trim(rh)? }
        } else {
            p + 12 - if lz != 0 { trim(lz)? } else { 2 + trim(lhh)? }
        }
    } else if rem != 0 {
        p + 8 - if bz != 0 { trim(bz)? } else { 2 + trim(bh)? }
    } else {
        p + 4 - trim(y)? - if y == 0 { trim(x)? } else { 0 }
    };
    if end <= at {
        return Err(fault(InvariantStage::Span));
    }
    Ok(end)
}
fn suffix(b: &mut Scratch, mut end: usize, exponent: i32) -> Checked<usize> {
    let n = u64::from(exponent.unsigned_abs());
    if n > 324 {
        return Err(fault(InvariantStage::DigitRange));
    }
    end = b.byte(end, b'e')?;
    if exponent < 0 {
        end = b.byte(end, b'-')?;
    }
    if n < 100 {
        return b.pair(end, n, true);
    }
    let q = (n * 0x290) >> 16;
    end = b.byte(end, b'0' + q as u8)?;
    b.pair(end, n - q * 100, false)
}
fn emit(bits: u64, b: &mut Scratch) -> Checked<usize> {
    let base = (bits >> 63) as usize;
    if base != 0 {
        b.byte(0, b'-')?;
    }
    let magnitude = bits & 0x7fffffffffffffff;
    if magnitude == 0 {
        return b.put(base, b"0.0");
    }
    let (c, q, kind) = coefficient((magnitude >> 52) as u32, magnitude & 0xfffffffffffff)?;
    match kind {
        Kind::Integral => {
            let end = integer(b, base, c, false)?;
            b.put(end, b".0")
        }
        Kind::Subnormal => {
            let mut end = integer(b, base + 1, c, true)?;
            // Exponent is based on untrimmed count, preserving original scale.
            let exponent = (end - base) as i32 - 326;
            b.byte(base, b.get(base + 1)?)?;
            b.byte(base + 1, b'.')?;
            while b.get(end - 1)? == b'0' {
                end -= 1;
            }
            if b.get(end - 1)? == b'.' {
                end -= 1;
            }
            suffix(b, end, exponent)
        }
        Kind::Normal => {
            let n = q + 17 - i32::from(c < 10_000_000_000_000_000);
            if (-5..=21).contains(&n) {
                let start = base + if n <= 0 { (2 - n) as usize } else { 0 };
                let digit_end = common(b, start, c)?;
                let source = start + n.max(0) as usize;
                let shift = usize::from(n > 0);
                let source_end = source.checked_add(16).ok_or(fault(InvariantStage::Span))?;
                let target_end = source_end
                    .checked_add(shift)
                    .ok_or(fault(InvariantStage::Span))?;
                if target_end > b.0.len() {
                    return Err(fault(InvariantStage::Span));
                }
                // Native memmove is logically equivalent to original two snapshots;
                // all64 bytes are initialized, including outside the logical result.
                b.0.copy_within(source..source_end, source + shift);
                b.byte(base + n.max(1) as usize, b'.')?;
                Ok((digit_end + shift).max((base as i32 + n + 2).max(0) as usize))
            } else {
                let mut end = common(b, base + 1, c)?;
                b.byte(base, b.get(base + 1)?)?;
                b.byte(base + 1, b'.')?;
                end -= usize::from(end == base + 2);
                suffix(b, end, n - 1)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn original_tables_and_checked_private_invariant_errors() {
        for n in 0..100 {
            assert_eq!(PAIRS[2 * n], b'0' + (n / 10) as u8);
            assert_eq!(PAIRS[2 * n + 1], b'0' + (n % 10) as u8);
            assert_eq!(
                TRIM[n],
                if n == 0 {
                    2
                } else if n % 10 == 0 {
                    1
                } else {
                    0
                }
            );
        }
        assert_eq!(cache(344), Err(fault(InvariantStage::CacheIndex)));
        assert_eq!(cache(-325), Err(fault(InvariantStage::CacheIndex)));
        assert_eq!(
            checked_normal(0, 0).err(),
            Some(fault(InvariantStage::Coefficient))
        );
        let mut s = Scratch([0xa5; 64]);
        assert_eq!(s.put(64, b"x"), Err(fault(InvariantStage::Span)));
        assert_eq!(
            s.pair(0, 100, false),
            Err(fault(InvariantStage::DigitRange))
        );
        assert_eq!(s.0, [0xa5; 64]);
    }
    #[test]
    fn every_four_digit_residue_and_integer_leading_length() {
        for n in 0..10000 {
            let mut s = Scratch([0; 64]);
            let end = fixed4(&mut s, 0, n).unwrap();
            assert_eq!(&s.0[..end], format!("{n:04}").as_bytes());
        }
        let mut samples = Vec::from_iter(1..10001u64);
        for k in 1..17 {
            for delta in [-1i64, 0, 1] {
                let n = (10u64.pow(k) as i64 + delta) as u64;
                if n < 100_000_000_000_000_000 {
                    samples.push(n);
                }
            }
        }
        for n in samples {
            let mut s = Scratch([0; 64]);
            let end = integer(&mut s, 0, n, true).unwrap();
            assert_eq!(&s.0[..end], n.to_string().as_bytes());
            if n < 1 << 53 {
                let end = integer(&mut s, 0, n, false).unwrap();
                assert_eq!(&s.0[..end], n.to_string().as_bytes());
            }
        }
    }
    #[test]
    fn common_all_trim_families_and_exponent_suffix_domain() {
        let mut cases = vec![1000000000000000, 10000000000000000, 99999999999999999];
        cases.extend((1000..100000).map(|n| n * 1_000_000_000_000));
        cases.extend((0..10000).map(|n| 1_000_000_000_000_000 + n * 100_000_000));
        cases.extend((1..10000).map(|n| 1_000_000_000_000_000 + n * 10000));
        cases.extend((1..10000).map(|n| 1_000_000_000_000_000 + 9999 * 10000 + n));
        for c in cases {
            let mut s = Scratch([0; 64]);
            let end = common(&mut s, 0, c).unwrap();
            let expected = c.to_string();
            assert_eq!(&s.0[..end], expected.trim_end_matches('0').as_bytes());
        }
        for exponent in -324..=309 {
            let mut s = Scratch([0; 64]);
            let end = suffix(&mut s, 0, exponent).unwrap();
            assert_eq!(&s.0[..end], format!("e{exponent}").as_bytes());
        }
    }
}
