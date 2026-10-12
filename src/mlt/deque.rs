//! Bounded Rust model of the approved `mlt_deque_` normal-return behavior.
//!
//! This is a safe Rust API adaptation, not a C ABI or STL container port.
//! Entries carry a Rust-only tag so typed reads cannot reinterpret a payload
//! through an unsupported mixed-kind path. The tag is not present in MLT.

use std::collections::VecDeque;
use std::ffi::c_void;
use std::mem::MaybeUninit;

const SLOT_BYTES: usize = 8;
const _: () = assert!(
    std::mem::size_of::<*mut c_void>() == SLOT_BYTES,
    "MLT deque source slots use 64-bit pointers"
);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DequePayloadKind {
    Pointer,
    Double,
    Int,
}

#[derive(Debug)]
struct Slot {
    bytes: [MaybeUninit<u8>; SLOT_BYTES],
    kind: DequePayloadKind,
    // Keep pointer provenance in a typed value. The raw slot bytes remain the
    // separate physical-bit model used by the contract and sorted callback.
    pointer_value: *mut c_void,
}

impl Slot {
    fn uninitialized(kind: DequePayloadKind) -> Self {
        Self {
            bytes: [MaybeUninit::uninit(); SLOT_BYTES],
            kind,
            pointer_value: std::ptr::null_mut(),
        }
    }

    fn pointer(value: *mut c_void) -> Self {
        let mut slot = Self::uninitialized(DequePayloadKind::Pointer);
        slot.write_u64(value as usize as u64);
        slot.pointer_value = value;
        slot
    }

    fn double(value: f64) -> Self {
        let mut slot = Self::uninitialized(DequePayloadKind::Double);
        slot.write_u64(value.to_bits());
        slot
    }

    fn int(value: i32) -> Self {
        let mut slot = Self::uninitialized(DequePayloadKind::Int);
        slot.write_u32(value as u32);
        slot
    }

    fn write_u32(&mut self, value: u32) {
        for (dst, byte) in self.bytes[..4].iter_mut().zip(value.to_le_bytes()) {
            dst.write(byte);
        }
    }

    fn write_u64(&mut self, value: u64) {
        for (dst, byte) in self.bytes.iter_mut().zip(value.to_le_bytes()) {
            dst.write(byte);
        }
    }

    fn read_u32(&self) -> u32 {
        let bytes = std::array::from_fn(|index| {
            // The Int constructor initializes exactly these four bytes.
            unsafe { self.bytes[index].assume_init() }
        });
        u32::from_le_bytes(bytes)
    }

    fn read_u64(&self) -> u64 {
        let bytes = std::array::from_fn(|index| {
            // Pointer and Double constructors initialize all eight bytes.
            unsafe { self.bytes[index].assume_init() }
        });
        u64::from_le_bytes(bytes)
    }

    fn check_kind(&self, expected: DequePayloadKind) -> Result<(), DequeError> {
        if self.kind == expected {
            Ok(())
        } else {
            Err(DequeError::TypeMismatch {
                expected,
                actual: self.kind,
            })
        }
    }

    fn as_pointer(&self) -> Result<*mut c_void, DequeError> {
        self.check_kind(DequePayloadKind::Pointer)?;
        Ok(self.pointer_value)
    }

    fn as_double(&self) -> Result<f64, DequeError> {
        self.check_kind(DequePayloadKind::Double)?;
        Ok(f64::from_bits(self.read_u64()))
    }

    fn as_int(&self) -> Result<i32, DequeError> {
        self.check_kind(DequePayloadKind::Int)?;
        Ok(self.read_u32() as i32)
    }

    fn pointer_word(&self) -> Result<u64, DequeError> {
        self.check_kind(DequePayloadKind::Pointer)?;
        Ok(self.read_u64())
    }
}

/// Independent safety errors. MLT's allocation and C++ exception behavior is
/// outside the approved contract, so Rust reports reserve and type failures.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DequeError {
    Allocation,
    CountOverflow,
    TypeMismatch {
        expected: DequePayloadKind,
        actual: DequePayloadKind,
    },
}

/// A safe Rust container with raw eight-byte payload slots.
///
/// `count` mirrors the original qword count. The backing `VecDeque` is a Rust
/// implementation choice and does not reproduce MSVC `std::deque` internals.
#[derive(Debug, Default)]
pub struct MltDeque {
    entries: VecDeque<Slot>,
    count: u64,
}

impl MltDeque {
    fn reserve_one(&mut self) -> Result<u64, DequeError> {
        let new_count = self.count.checked_add(1).ok_or(DequeError::CountOverflow)?;
        self.entries
            .try_reserve(1)
            .map_err(|_| DequeError::Allocation)?;
        Ok(new_count)
    }

    fn push_back_slot(&mut self, slot: Slot) -> Result<(), DequeError> {
        let new_count = self.reserve_one()?;
        self.entries.push_back(slot);
        self.count = new_count;
        Ok(())
    }

    fn push_front_slot(&mut self, slot: Slot) -> Result<(), DequeError> {
        let new_count = self.reserve_one()?;
        self.entries.push_front(slot);
        self.count = new_count;
        Ok(())
    }

    fn valid_index(&self, index: i32, allow_end: bool) -> Option<usize> {
        if index < 0 {
            return None;
        }
        let index = index as u64;
        let in_bounds = if allow_end {
            index <= self.count
        } else {
            index < self.count
        };
        in_bounds.then_some(index as usize)
    }

    fn peek_slot(&self, index: usize) -> Option<&Slot> {
        self.entries.get(index)
    }

    fn insert_pointer_at(&mut self, index: usize, value: *mut c_void) -> Result<(), DequeError> {
        let new_count = self.reserve_one()?;
        self.entries.insert(index, Slot::pointer(value));
        self.count = new_count;
        Ok(())
    }

    fn remove_slot_at(&mut self, index: usize) {
        self.entries.remove(index);
        self.count -= 1;
        if self.count == 0 {
            self.entries.clear();
        }
    }
}

/// Original name: `mlt_deque_init` (`0x180017240`).
pub fn mlt_deque_init() -> Result<MltDeque, DequeError> {
    let mut deque = MltDeque::default();
    deque
        .entries
        .try_reserve(1)
        .map_err(|_| DequeError::Allocation)?;
    Ok(deque)
}

/// Original name: `mlt_deque_close` (`0x180017200`).
///
/// Dropping the Rust wrapper releases only the raw slot storage. It does not
/// dereference or destroy pointer payloads.
pub fn mlt_deque_close(deque: Option<MltDeque>) {
    drop(deque);
}

/// Original name: `mlt_deque_count` (`0x180017230`).
///
/// The export exposes the signed low dword of the internal qword count.
pub fn mlt_deque_count(deque: Option<&MltDeque>) -> i32 {
    deque.map_or(0, |deque| deque.count as u32 as i32)
}

/// Original name: `mlt_deque_push_back` (`0x180017370`).
pub fn mlt_deque_push_back(
    deque: Option<&mut MltDeque>,
    value: *mut c_void,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_back_slot(Slot::pointer(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_push_back_double` (`0x180017380`).
pub fn mlt_deque_push_back_double(
    deque: Option<&mut MltDeque>,
    value: f64,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_back_slot(Slot::double(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_push_back_int` (`0x180017390`).
pub fn mlt_deque_push_back_int(
    deque: Option<&mut MltDeque>,
    value: i32,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_back_slot(Slot::int(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_push_front` (`0x1800173a0`).
pub fn mlt_deque_push_front(
    deque: Option<&mut MltDeque>,
    value: *mut c_void,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_front_slot(Slot::pointer(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_push_front_double` (`0x1800173b0`).
pub fn mlt_deque_push_front_double(
    deque: Option<&mut MltDeque>,
    value: f64,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_front_slot(Slot::double(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_push_front_int` (`0x1800173c0`).
pub fn mlt_deque_push_front_int(
    deque: Option<&mut MltDeque>,
    value: i32,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    deque.push_front_slot(Slot::int(value))?;
    Ok(0)
}

/// Original name: `mlt_deque_peek` (`0x1800172a0`).
pub fn mlt_deque_peek(deque: Option<&MltDeque>, index: i32) -> Result<*mut c_void, DequeError> {
    let Some(deque) = deque else {
        return Ok(std::ptr::null_mut());
    };
    let Some(index) = deque.valid_index(index, false) else {
        return Ok(std::ptr::null_mut());
    };
    deque
        .peek_slot(index)
        .map_or(Ok(std::ptr::null_mut()), Slot::as_pointer)
}

/// Original name: `mlt_deque_peek_front` (`0x1800172e0`).
pub fn mlt_deque_peek_front(deque: Option<&MltDeque>) -> Result<*mut c_void, DequeError> {
    let Some(deque) = deque else {
        return Ok(std::ptr::null_mut());
    };
    deque
        .entries
        .front()
        .map_or(Ok(std::ptr::null_mut()), Slot::as_pointer)
}

/// Original name: `mlt_deque_peek_front_double` (`0x1800172f0`).
pub fn mlt_deque_peek_front_double(deque: Option<&MltDeque>) -> Result<f64, DequeError> {
    let Some(deque) = deque else { return Ok(0.0) };
    deque.entries.front().map_or(Ok(0.0), Slot::as_double)
}

/// Original name: `mlt_deque_peek_front_int` (`0x180017300`).
pub fn mlt_deque_peek_front_int(deque: Option<&MltDeque>) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(0) };
    deque.entries.front().map_or(Ok(0), Slot::as_int)
}

/// Original name: `mlt_deque_peek_back` (`0x1800172b0`).
pub fn mlt_deque_peek_back(deque: Option<&MltDeque>) -> Result<*mut c_void, DequeError> {
    let Some(deque) = deque else {
        return Ok(std::ptr::null_mut());
    };
    deque
        .entries
        .back()
        .map_or(Ok(std::ptr::null_mut()), Slot::as_pointer)
}

/// Original name: `mlt_deque_peek_back_double` (`0x1800172c0`).
pub fn mlt_deque_peek_back_double(deque: Option<&MltDeque>) -> Result<f64, DequeError> {
    let Some(deque) = deque else { return Ok(0.0) };
    deque.entries.back().map_or(Ok(0.0), Slot::as_double)
}

/// Original name: `mlt_deque_peek_back_int` (`0x1800172d0`).
pub fn mlt_deque_peek_back_int(deque: Option<&MltDeque>) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(0) };
    deque.entries.back().map_or(Ok(0), Slot::as_int)
}

/// Original name: `mlt_deque_pop_front` (`0x180017340`).
pub fn mlt_deque_pop_front(deque: Option<&mut MltDeque>) -> Result<*mut c_void, DequeError> {
    let Some(deque) = deque else {
        return Ok(std::ptr::null_mut());
    };
    let Some(slot) = deque.entries.front() else {
        return Ok(std::ptr::null_mut());
    };
    let value = slot.as_pointer()?;
    deque.remove_slot_at(0);
    Ok(value)
}

/// Original name: `mlt_deque_pop_front_double` (`0x180017350`).
pub fn mlt_deque_pop_front_double(deque: Option<&mut MltDeque>) -> Result<f64, DequeError> {
    let Some(deque) = deque else { return Ok(0.0) };
    let Some(slot) = deque.entries.front() else {
        return Ok(0.0);
    };
    let value = slot.as_double()?;
    deque.remove_slot_at(0);
    Ok(value)
}

/// Original name: `mlt_deque_pop_front_int` (`0x180017360`).
pub fn mlt_deque_pop_front_int(deque: Option<&mut MltDeque>) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(0) };
    let Some(slot) = deque.entries.front() else {
        return Ok(0);
    };
    let value = slot.as_int()?;
    deque.remove_slot_at(0);
    Ok(value)
}

/// Original name: `mlt_deque_pop_back` (`0x180017310`).
pub fn mlt_deque_pop_back(deque: Option<&mut MltDeque>) -> Result<*mut c_void, DequeError> {
    let Some(deque) = deque else {
        return Ok(std::ptr::null_mut());
    };
    let Some(slot) = deque.entries.back() else {
        return Ok(std::ptr::null_mut());
    };
    let value = slot.as_pointer()?;
    let index = deque.entries.len() - 1;
    deque.remove_slot_at(index);
    Ok(value)
}

/// Original name: `mlt_deque_pop_back_double` (`0x180017320`).
pub fn mlt_deque_pop_back_double(deque: Option<&mut MltDeque>) -> Result<f64, DequeError> {
    let Some(deque) = deque else { return Ok(0.0) };
    let Some(slot) = deque.entries.back() else {
        return Ok(0.0);
    };
    let value = slot.as_double()?;
    let index = deque.entries.len() - 1;
    deque.remove_slot_at(index);
    Ok(value)
}

/// Original name: `mlt_deque_pop_back_int` (`0x180017330`).
pub fn mlt_deque_pop_back_int(deque: Option<&mut MltDeque>) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(0) };
    let Some(slot) = deque.entries.back() else {
        return Ok(0);
    };
    let value = slot.as_int()?;
    let index = deque.entries.len() - 1;
    deque.remove_slot_at(index);
    Ok(value)
}

/// Original name: `mlt_deque_insert_at` (`0x180017290`).
pub fn mlt_deque_insert_at(
    deque: Option<&mut MltDeque>,
    index: i32,
    value: *mut c_void,
) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    let Some(index) = deque.valid_index(index, true) else {
        return Ok(1);
    };
    deque.insert_pointer_at(index, value)?;
    Ok(0)
}

/// Original name: `mlt_deque_remove_at` (`0x1800173d0`).
pub fn mlt_deque_remove_at(deque: Option<&mut MltDeque>, index: i32) -> Result<i32, DequeError> {
    let Some(deque) = deque else { return Ok(1) };
    let Some(index) = deque.valid_index(index, false) else {
        return Ok(1);
    };
    deque.remove_slot_at(index);
    Ok(0)
}

/// Original name: `mlt_deque_insert` (`0x180017270`).
///
/// The closure is a Rust safety adaptation for the original callback. It gets
/// the existing pointer payload's first qword and the candidate pointer qword.
/// A negative result advances the lower bound. Zero or positive results move
/// the upper bound. Equal entries are inserted before the first equivalent.
pub fn mlt_deque_insert<F>(
    deque: Option<&mut MltDeque>,
    value: *mut c_void,
    mut compare: Option<F>,
) -> Result<i32, DequeError>
where
    F: FnMut(u64, u64) -> i32,
{
    let (Some(deque), Some(compare)) = (deque, compare.as_mut()) else {
        return Ok(1);
    };
    let new_count = deque.reserve_one()?;
    let candidate = value as usize as u64;
    let mut lower = 0usize;
    let mut upper = deque.entries.len();
    while lower < upper {
        let middle = lower + (upper - lower) / 2;
        let existing = deque.entries[middle].pointer_word()?;
        if compare(existing, candidate) < 0 {
            lower = middle + 1;
        } else {
            upper = middle;
        }
    }
    deque.entries.insert(lower, Slot::pointer(value));
    deque.count = new_count;
    Ok(0)
}

#[cfg(test)]
mod slot_tests {
    use super::{DequePayloadKind, Slot};

    #[test]
    fn integer_slot_initializes_and_reads_only_four_bytes() {
        let slot = Slot::int(-7);
        assert_eq!(slot.kind, DequePayloadKind::Int);
        assert_eq!(slot.as_int().unwrap(), -7);
        assert_eq!(
            slot.bytes[..4]
                .iter()
                .map(|byte| unsafe { byte.assume_init() })
                .collect::<Vec<_>>(),
            (-7i32).to_le_bytes()
        );
    }

    #[test]
    fn typed_reads_reject_unapproved_mixed_kind_access() {
        let slot = Slot::int(0x1234);
        assert_eq!(
            slot.as_double(),
            Err(super::DequeError::TypeMismatch {
                expected: DequePayloadKind::Double,
                actual: DequePayloadKind::Int
            })
        );
        assert_eq!(
            slot.as_pointer(),
            Err(super::DequeError::TypeMismatch {
                expected: DequePayloadKind::Pointer,
                actual: DequePayloadKind::Int
            })
        );
    }

    #[test]
    fn count_export_uses_the_signed_low_dword_of_its_qword() {
        let deque = super::MltDeque {
            count: 0x0000_0000_8000_0001,
            ..super::MltDeque::default()
        };
        assert_eq!(super::mlt_deque_count(Some(&deque)), i32::MIN + 1);
    }

    #[test]
    fn count_overflow_is_an_explicit_safe_error() {
        let mut deque = super::MltDeque {
            count: u64::MAX,
            ..super::MltDeque::default()
        };
        assert_eq!(deque.reserve_one(), Err(super::DequeError::CountOverflow));
    }
}
