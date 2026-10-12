#![allow(clippy::needless_borrow)]

#[path = "../src/mlt/deque.rs"]
pub mod deque;

use deque::*;
use std::ffi::c_void;
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

const CONTRACT_CASES: &str = include_str!("fixtures/mlt/deque/contract-cases.json");

fn ptr(value: usize) -> *mut c_void {
    value as *mut c_void
}

#[test]
fn static_fixture_pins_all_approved_original_exports() {
    let exports = [
        ("mlt_deque_close", "0x180017200"),
        ("mlt_deque_count", "0x180017230"),
        ("mlt_deque_init", "0x180017240"),
        ("mlt_deque_insert", "0x180017270"),
        ("mlt_deque_insert_at", "0x180017290"),
        ("mlt_deque_peek", "0x1800172a0"),
        ("mlt_deque_peek_back", "0x1800172b0"),
        ("mlt_deque_peek_back_double", "0x1800172c0"),
        ("mlt_deque_peek_back_int", "0x1800172d0"),
        ("mlt_deque_peek_front", "0x1800172e0"),
        ("mlt_deque_peek_front_double", "0x1800172f0"),
        ("mlt_deque_peek_front_int", "0x180017300"),
        ("mlt_deque_pop_back", "0x180017310"),
        ("mlt_deque_pop_back_double", "0x180017320"),
        ("mlt_deque_pop_back_int", "0x180017330"),
        ("mlt_deque_pop_front", "0x180017340"),
        ("mlt_deque_pop_front_double", "0x180017350"),
        ("mlt_deque_pop_front_int", "0x180017360"),
        ("mlt_deque_push_back", "0x180017370"),
        ("mlt_deque_push_back_double", "0x180017380"),
        ("mlt_deque_push_back_int", "0x180017390"),
        ("mlt_deque_push_front", "0x1800173a0"),
        ("mlt_deque_push_front_double", "0x1800173b0"),
        ("mlt_deque_push_front_int", "0x1800173c0"),
        ("mlt_deque_remove_at", "0x1800173d0"),
    ];
    for (name, address) in exports {
        assert!(CONTRACT_CASES.contains(&format!(
            "\"name\": \"{name}\",\n      \"address\": \"{address}\""
        )));
    }
    assert_eq!(exports.len(), 25);
    assert_eq!(
        CONTRACT_CASES
            .matches("\"approved_normal_return_contract\":")
            .count(),
        25
    );
    assert_eq!(
        CONTRACT_CASES.matches("\"original_byte_check\":").count(),
        25
    );
    assert!(
        CONTRACT_CASES.contains("0d37a6244d9a923c3a1fbf1bd8917dde83479362be3df5653ade171a4640076a")
    );
}

#[test]
fn init_close_and_null_wrapper_contracts() {
    let deque = mlt_deque_init().unwrap();
    assert_eq!(mlt_deque_count(Some(&deque)), 0);
    assert_eq!(mlt_deque_count(None), 0);
    assert_eq!(mlt_deque_push_back(None, ptr(1)).unwrap(), 1);
    assert_eq!(mlt_deque_push_front(None, ptr(1)).unwrap(), 1);
    assert_eq!(mlt_deque_push_back_double(None, 1.0).unwrap(), 1);
    assert_eq!(mlt_deque_push_front_double(None, 1.0).unwrap(), 1);
    assert_eq!(mlt_deque_push_back_int(None, 1).unwrap(), 1);
    assert_eq!(mlt_deque_push_front_int(None, 1).unwrap(), 1);
    assert_eq!(mlt_deque_peek(None, 0).unwrap(), std::ptr::null_mut());
    assert_eq!(mlt_deque_peek_front(None).unwrap(), std::ptr::null_mut());
    assert_eq!(mlt_deque_peek_back(None).unwrap(), std::ptr::null_mut());
    assert_eq!(mlt_deque_peek_front_double(None).unwrap(), 0.0);
    assert_eq!(mlt_deque_peek_back_double(None).unwrap(), 0.0);
    assert_eq!(mlt_deque_peek_front_int(None).unwrap(), 0);
    assert_eq!(mlt_deque_peek_back_int(None).unwrap(), 0);
    assert_eq!(mlt_deque_pop_front(None).unwrap(), std::ptr::null_mut());
    assert_eq!(mlt_deque_pop_back(None).unwrap(), std::ptr::null_mut());
    assert_eq!(mlt_deque_pop_front_double(None).unwrap(), 0.0);
    assert_eq!(mlt_deque_pop_back_double(None).unwrap(), 0.0);
    assert_eq!(mlt_deque_pop_front_int(None).unwrap(), 0);
    assert_eq!(mlt_deque_pop_back_int(None).unwrap(), 0);
    assert_eq!(mlt_deque_insert_at(None, 0, ptr(1)).unwrap(), 1);
    assert_eq!(mlt_deque_remove_at(None, 0).unwrap(), 1);
    assert_eq!(
        mlt_deque_insert::<fn(u64, u64) -> i32>(None, ptr(1), None).unwrap(),
        1
    );
    mlt_deque_close(None);
    mlt_deque_close(Some(deque));
}

#[test]
fn pointer_push_peek_pop_preserves_order_and_null_payloads() {
    let mut deque = mlt_deque_init().unwrap();
    assert_eq!(
        mlt_deque_push_back(Some(&mut deque), ptr(0x1234)).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_push_front(Some(&mut deque), ptr(0x5678)).unwrap(),
        0
    );
    assert_eq!(mlt_deque_count(Some(&deque)), 2);
    assert_eq!(mlt_deque_peek(Some(&deque), 0).unwrap(), ptr(0x5678));
    assert_eq!(mlt_deque_peek(Some(&deque), 1).unwrap(), ptr(0x1234));
    assert_eq!(
        mlt_deque_peek(Some(&deque), -1).unwrap(),
        std::ptr::null_mut()
    );
    assert_eq!(
        mlt_deque_peek(Some(&deque), 2).unwrap(),
        std::ptr::null_mut()
    );
    assert_eq!(mlt_deque_peek_front(Some(&deque)).unwrap(), ptr(0x5678));
    assert_eq!(mlt_deque_peek_back(Some(&deque)).unwrap(), ptr(0x1234));
    assert_eq!(mlt_deque_pop_front(Some(&mut deque)).unwrap(), ptr(0x5678));
    assert_eq!(mlt_deque_pop_back(Some(&mut deque)).unwrap(), ptr(0x1234));
    assert_eq!(mlt_deque_count(Some(&deque)), 0);
    assert_eq!(
        mlt_deque_pop_front(Some(&mut deque)).unwrap(),
        std::ptr::null_mut()
    );
    assert_eq!(
        mlt_deque_pop_back(Some(&mut deque)).unwrap(),
        std::ptr::null_mut()
    );

    assert_eq!(
        mlt_deque_push_back(Some(&mut deque), std::ptr::null_mut()).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_peek_front(Some(&deque)).unwrap(),
        std::ptr::null_mut()
    );
    assert_eq!(
        mlt_deque_pop_back(Some(&mut deque)).unwrap(),
        std::ptr::null_mut()
    );
    assert_eq!(mlt_deque_count(Some(&deque)), 0);
}

#[test]
fn close_does_not_destroy_pointer_payloads_in_the_rust_adaptation() {
    struct Probe(Arc<AtomicBool>);
    impl Drop for Probe {
        fn drop(&mut self) {
            self.0.store(true, Ordering::SeqCst);
        }
    }

    let dropped = Arc::new(AtomicBool::new(false));
    let raw = Box::into_raw(Box::new(Probe(Arc::clone(&dropped))));
    let mut deque = mlt_deque_init().unwrap();
    assert_eq!(
        mlt_deque_push_back(Some(&mut deque), raw.cast()).unwrap(),
        0
    );
    mlt_deque_close(Some(deque));
    assert!(!dropped.load(Ordering::SeqCst));
    // The test retains ownership and releases its own allocation.
    unsafe { drop(Box::from_raw(raw)) };
    assert!(dropped.load(Ordering::SeqCst));
}

#[test]
fn double_push_peek_pop_preserves_all_payload_bits() {
    let mut deque = mlt_deque_init().unwrap();
    let first = f64::from_bits(0x7ff8_1234_5678_9abc);
    let last = -19.25;
    assert_eq!(
        mlt_deque_push_back_double(Some(&mut deque), first).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_push_front_double(Some(&mut deque), last).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_peek_front_double(Some(&deque)).unwrap().to_bits(),
        last.to_bits()
    );
    assert_eq!(
        mlt_deque_peek_back_double(Some(&deque)).unwrap().to_bits(),
        first.to_bits()
    );
    assert_eq!(
        mlt_deque_pop_front_double(Some(&mut deque))
            .unwrap()
            .to_bits(),
        last.to_bits()
    );
    assert_eq!(
        mlt_deque_pop_back_double(Some(&mut deque))
            .unwrap()
            .to_bits(),
        first.to_bits()
    );
    assert_eq!(mlt_deque_pop_front_double(Some(&mut deque)).unwrap(), 0.0);
    assert_eq!(mlt_deque_pop_back_double(Some(&mut deque)).unwrap(), 0.0);
}

#[test]
fn int_push_peek_pop_uses_signed_low_four_bytes() {
    let mut deque = mlt_deque_init().unwrap();
    assert_eq!(
        mlt_deque_push_back_int(Some(&mut deque), i32::MIN).unwrap(),
        0
    );
    assert_eq!(mlt_deque_push_front_int(Some(&mut deque), -7).unwrap(), 0);
    assert_eq!(mlt_deque_peek_front_int(Some(&deque)).unwrap(), -7);
    assert_eq!(mlt_deque_peek_back_int(Some(&deque)).unwrap(), i32::MIN);
    assert_eq!(mlt_deque_pop_front_int(Some(&mut deque)).unwrap(), -7);
    assert_eq!(mlt_deque_pop_back_int(Some(&mut deque)).unwrap(), i32::MIN);
    assert_eq!(mlt_deque_pop_front_int(Some(&mut deque)).unwrap(), 0);
    assert_eq!(mlt_deque_pop_back_int(Some(&mut deque)).unwrap(), 0);
}

#[test]
fn insert_at_and_remove_at_use_signed_low_dword_bounds_and_preserve_order() {
    let mut deque = mlt_deque_init().unwrap();
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), 0, ptr(10)).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), 1, ptr(30)).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), 1, ptr(20)).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), -1, ptr(40)).unwrap(),
        1
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), 4, ptr(40)).unwrap(),
        1
    );
    assert_eq!(mlt_deque_count(Some(&deque)), 3);
    assert_eq!(mlt_deque_peek(Some(&deque), 0).unwrap(), ptr(10));
    assert_eq!(mlt_deque_peek(Some(&deque), 1).unwrap(), ptr(20));
    assert_eq!(mlt_deque_peek(Some(&deque), 2).unwrap(), ptr(30));
    assert_eq!(mlt_deque_remove_at(Some(&mut deque), -1).unwrap(), 1);
    assert_eq!(mlt_deque_remove_at(Some(&mut deque), 3).unwrap(), 1);
    assert_eq!(mlt_deque_remove_at(Some(&mut deque), 1).unwrap(), 0);
    assert_eq!(mlt_deque_count(Some(&deque)), 2);
    assert_eq!(mlt_deque_peek(Some(&deque), 0).unwrap(), ptr(10));
    assert_eq!(mlt_deque_peek(Some(&deque), 1).unwrap(), ptr(30));
    assert_eq!(mlt_deque_remove_at(Some(&mut deque), 0).unwrap(), 0);
    assert_eq!(mlt_deque_remove_at(Some(&mut deque), 0).unwrap(), 0);
    assert_eq!(mlt_deque_count(Some(&deque)), 0);
}

#[test]
fn sorted_insert_uses_existing_then_candidate_and_inserts_before_equals() {
    let mut deque = mlt_deque_init().unwrap();
    let keyed_ptr = |key: usize, id: usize| ptr((key << 8) | id);
    for value in [
        keyed_ptr(10, 0),
        keyed_ptr(30, 0),
        keyed_ptr(20, 1),
        keyed_ptr(20, 2),
    ] {
        assert_eq!(
            mlt_deque_insert(
                Some(&mut deque),
                value,
                Some(|existing, candidate| {
                    ((existing >> 8) as i64 - (candidate >> 8) as i64) as i32
                })
            )
            .unwrap(),
            0
        );
    }
    assert_eq!(mlt_deque_count(Some(&deque)), 4);
    assert_eq!(mlt_deque_peek(Some(&deque), 0).unwrap(), keyed_ptr(10, 0));
    assert_eq!(mlt_deque_peek(Some(&deque), 1).unwrap(), keyed_ptr(20, 2));
    assert_eq!(mlt_deque_peek(Some(&deque), 2).unwrap(), keyed_ptr(20, 1));
    assert_eq!(mlt_deque_peek(Some(&deque), 3).unwrap(), keyed_ptr(30, 0));

    assert_eq!(
        mlt_deque_insert(Some(&mut deque), ptr(40), None::<fn(u64, u64) -> i32>).unwrap(),
        1
    );
}

#[test]
fn typed_reads_fail_safely_without_removing_mismatched_entry() {
    let mut deque = mlt_deque_init().unwrap();
    mlt_deque_push_back_int(Some(&mut deque), 11).unwrap();
    assert!(matches!(
        mlt_deque_peek_front_double(Some(&deque)),
        Err(DequeError::TypeMismatch { .. })
    ));
    assert!(matches!(
        mlt_deque_pop_front(Some(&mut deque)),
        Err(DequeError::TypeMismatch { .. })
    ));
    assert_eq!(mlt_deque_count(Some(&deque)), 1);
    assert_eq!(mlt_deque_pop_front_int(Some(&mut deque)).unwrap(), 11);
}
