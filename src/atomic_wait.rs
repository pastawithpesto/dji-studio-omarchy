//! Pure contracts for two exports of the original DJI Studio copy of
//! `msvcp140_atomic_wait.dll`.
//!
//! Source pin: build 1.0.0.30839, 57,376 bytes, SHA-256
//! `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`.
//! Static evidence lives in `docs/evidence/atomic-wait-timeouts`.
//! Task record and independent review live in
//! `docs/evidence/headless-atomic-wait-rust`.
//!
//! The original bodies read the imported `KERNEL32.dll!GetTickCount64`
//! exactly once on each finite-input path and never on a sentinel path.
//! The caller supplies that single time sample as an `FnMut() -> u64`
//! clock. This module implements no wait loop, no clock origin, no
//! Windows ABI surface, and no runtime integration.
//!
//! The formal original C++ parameter and return declarations are unknown.
//! Both functions return the observed `RAX` result bits as `u64`. Every
//! `__std_atomic_wait_get_remaining_timeout` return path writes `EAX`,
//! so its observed result is zero-extended and never sets a bit above
//! bit 31.

/// Upper bound applied by the original `__std_atomic_wait_get_remaining_timeout`
/// body. The instruction bytes encode the immediate `0x337f9800`
/// (864000000). Under the separately cited `GetTickCount64` millisecond
/// unit this value is 10 days. The DLL bytes alone establish neither unit.
const REMAINING_TIMEOUT_CAP: u64 = 0x337F_9800;

/// Original export, ordinal 11, VA `0x1800015c0`, 33 bytes, body SHA-256
/// `91a621460251e107081a5c4abe58a32f74745cd2b6d93cc8fca49a9dca158b88`.
///
/// An input of [`u64::MAX`] returns [`u64::MAX`] without sampling the
/// clock. Any other input samples the clock once and returns the 64-bit
/// wrapping sum of the sample and the input. The original `ADD` has no
/// carry check and no saturation, so a finite sum can produce
/// [`u64::MAX`] or wrap through zero.
pub fn __std_atomic_wait_get_deadline(input: u64, mut clock: impl FnMut() -> u64) -> u64 {
    if input == u64::MAX {
        return input;
    }
    clock().wrapping_add(input)
}

/// Original export, ordinal 12, VA `0x1800015f0`, 56 bytes, body SHA-256
/// `2090187ba92fcec6d04afdfdf1e278feaeb834ad6bef76ad6b7f1c62370516ad`.
///
/// A deadline of [`u64::MAX`] returns `0x0000_0000_FFFF_FFFF` without
/// sampling the clock. Any other deadline samples the clock once. The
/// comparison is unsigned: a clock value at or above the deadline
/// returns 0, equality included. A future deadline returns the unsigned
/// difference clamped at [`REMAINING_TIMEOUT_CAP`]; equality with the
/// cap returns the cap value. The observed result is zero-extended and
/// never sets a bit above bit 31.
pub fn __std_atomic_wait_get_remaining_timeout(
    deadline: u64,
    mut clock: impl FnMut() -> u64,
) -> u64 {
    if deadline == u64::MAX {
        return u32::MAX as u64;
    }
    let now = clock();
    if now >= deadline {
        return 0;
    }
    (deadline - now).min(REMAINING_TIMEOUT_CAP)
}
