//! Integration tests for the atomic-wait timeout contracts.
//!
//! Expected values are pinned hex literals. The 11 base vectors repeat
//! `docs/evidence/atomic-wait-timeouts/reference-model-results.txt`.
//! The other expectations follow the pinned instruction semantics in
//! `docs/evidence/atomic-wait-timeouts/source-map.json` and the approved
//! contract review. No expected value is computed by this crate.

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use dji_reframe::atomic_wait::{
    __std_atomic_wait_get_deadline, __std_atomic_wait_get_remaining_timeout,
};

/// A clock that returns `value` and counts its calls.
fn counting_clock(value: u64) -> (impl FnMut() -> u64, Rc<Cell<u32>>) {
    let calls = Rc::new(Cell::new(0));
    let counter = Rc::clone(&calls);
    (
        move || {
            counter.set(counter.get() + 1);
            value
        },
        calls,
    )
}

enum Call {
    Deadline,
    Remaining,
}

struct Vector {
    name: &'static str,
    call: Call,
    input: u64,
    tick: u64,
    expected: u64,
    expected_clock_calls: u32,
}

/// The 11 static reference vectors with their pinned names, values and
/// call counts from the saved evidence packet.
const REFERENCE_VECTORS: &[Vector] = &[
    Vector {
        name: "zero-duration-deadline",
        call: Call::Deadline,
        input: 0,
        tick: 100,
        expected: 0x64,
        expected_clock_calls: 1,
    },
    Vector {
        name: "deadline-is-now",
        call: Call::Remaining,
        input: 100,
        tick: 100,
        expected: 0x0,
        expected_clock_calls: 1,
    },
    Vector {
        name: "deadline-in-past",
        call: Call::Remaining,
        input: 99,
        tick: 100,
        expected: 0x0,
        expected_clock_calls: 1,
    },
    Vector {
        name: "one-unit-remaining",
        call: Call::Remaining,
        input: 101,
        tick: 100,
        expected: 0x1,
        expected_clock_calls: 1,
    },
    Vector {
        name: "just-below-cap",
        call: Call::Remaining,
        input: 864000099,
        tick: 100,
        expected: 0x337f97ff,
        expected_clock_calls: 1,
    },
    Vector {
        name: "exact-cap",
        call: Call::Remaining,
        input: 864000100,
        tick: 100,
        expected: 0x337f9800,
        expected_clock_calls: 1,
    },
    Vector {
        name: "above-cap",
        call: Call::Remaining,
        input: 864000101,
        tick: 100,
        expected: 0x337f9800,
        expected_clock_calls: 1,
    },
    Vector {
        name: "infinite-timeout-input",
        call: Call::Deadline,
        input: u64::MAX,
        tick: 100,
        expected: 0xffffffffffffffff,
        expected_clock_calls: 0,
    },
    Vector {
        name: "infinite-deadline-is-32-bit-infinite",
        call: Call::Remaining,
        input: u64::MAX,
        tick: 100,
        expected: 0xffffffff,
        expected_clock_calls: 0,
    },
    Vector {
        name: "finite-addition-collides-with-infinite-sentinel",
        call: Call::Deadline,
        input: 10,
        tick: u64::MAX - 10,
        expected: 0xffffffffffffffff,
        expected_clock_calls: 1,
    },
    Vector {
        name: "finite-addition-wraps-to-zero",
        call: Call::Deadline,
        input: 11,
        tick: u64::MAX - 10,
        expected: 0x0,
        expected_clock_calls: 1,
    },
];

#[test]
fn reference_vectors_match_pinned_model() {
    for vector in REFERENCE_VECTORS {
        let (clock, calls) = counting_clock(vector.tick);
        let actual = match vector.call {
            Call::Deadline => __std_atomic_wait_get_deadline(vector.input, clock),
            Call::Remaining => __std_atomic_wait_get_remaining_timeout(vector.input, clock),
        };
        assert_eq!(actual, vector.expected, "vector {}", vector.name);
        assert_eq!(
            calls.get(),
            vector.expected_clock_calls,
            "vector {} clock calls",
            vector.name
        );
    }
}

#[test]
fn sentinel_paths_return_pinned_bits_without_sampling_the_clock() {
    let (clock, calls) = counting_clock(100);
    assert_eq!(
        __std_atomic_wait_get_deadline(u64::MAX, clock),
        0xffff_ffff_ffff_ffff
    );
    assert_eq!(
        calls.get(),
        0,
        "deadline sentinel must not sample the clock"
    );

    let (clock, calls) = counting_clock(100);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(u64::MAX, clock),
        0x0000_0000_ffff_ffff
    );
    assert_eq!(
        calls.get(),
        0,
        "remaining sentinel must not sample the clock"
    );
}

#[test]
fn finite_paths_sample_the_clock_exactly_once() {
    let (clock, calls) = counting_clock(0x100);
    assert_eq!(__std_atomic_wait_get_deadline(0x40, clock), 0x140);
    assert_eq!(calls.get(), 1, "deadline finite path must sample once");

    let (clock, calls) = counting_clock(0x100);
    assert_eq!(__std_atomic_wait_get_remaining_timeout(0x101, clock), 0x1);
    assert_eq!(calls.get(), 1, "remaining finite path must sample once");
}

#[test]
fn clock_sampling_side_effects_are_preserved() {
    let samples = Rc::new(RefCell::new(Vec::<u64>::new()));
    let record = Rc::clone(&samples);
    let clock = move || {
        record.borrow_mut().push(0x0123_4567_89ab_cdef);
        0x0123_4567_89ab_cdef
    };
    assert_eq!(
        __std_atomic_wait_get_deadline(2, clock),
        0x0123_4567_89ab_cdf1
    );
    assert_eq!(
        *samples.borrow(),
        vec![0x0123_4567_89ab_cdef],
        "deadline sample"
    );

    let samples = Rc::new(RefCell::new(Vec::<u64>::new()));
    let record = Rc::clone(&samples);
    let clock = move || {
        record.borrow_mut().push(3);
        3
    };
    assert_eq!(__std_atomic_wait_get_remaining_timeout(10, clock), 7);
    assert_eq!(*samples.borrow(), vec![3], "remaining sample");
}

#[test]
fn deadline_wraps_to_the_sentinel_value() {
    let (clock, calls) = counting_clock(0xffff_ffff_0000_0000);
    assert_eq!(
        __std_atomic_wait_get_deadline(0xffff_ffff, clock),
        0xffff_ffff_ffff_ffff,
        "finite sum may collide with the sentinel"
    );
    assert_eq!(calls.get(), 1);
}

#[test]
fn deadline_wraps_through_zero() {
    let (clock, calls) = counting_clock(u64::MAX);
    assert_eq!(
        __std_atomic_wait_get_deadline(1, clock),
        0,
        "the machine add has no carry check"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0xffff_ffff_ffff_fffe);
    assert_eq!(__std_atomic_wait_get_deadline(3, clock), 1);
    assert_eq!(calls.get(), 1);
}

#[test]
fn remaining_treats_values_as_unsigned() {
    // A signed comparison would read 0xf000... as negative and return 0.
    let (clock, calls) = counting_clock(0x8000_0000_0000_0000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0xf000_0000_0000_0000, clock),
        0x337f_9800
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0x8000_0000_0000_0000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0x8000_0000_0000_0001, clock),
        0x1
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0xf000_0000_0000_0000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0x8000_0000_0000_0000, clock),
        0x0,
        "unsigned expired compare"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(u64::MAX);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(u64::MAX - 1, clock),
        0x0
    );
    assert_eq!(calls.get(), 1);
}

#[test]
fn remaining_returns_zero_for_expired_and_equal_deadlines() {
    let (clock, calls) = counting_clock(100);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0, clock),
        0,
        "finite zero deadline with a large clock value"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(1000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(1000, clock),
        0,
        "equality is expired"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(1000);
    assert_eq!(__std_atomic_wait_get_remaining_timeout(1001, clock), 1);
    assert_eq!(calls.get(), 1);
}

#[test]
fn remaining_clamps_at_the_cap_boundaries() {
    let (clock, calls) = counting_clock(0x1000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0x1000 + 0x337f_97ff, clock),
        0x337f_97ff,
        "one below the cap returns the difference"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0x1000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0x1000 + 0x337f_9800, clock),
        0x337f_9800,
        "equality with the cap returns the cap value"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0x1000);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(0x1000 + 0x337f_9801, clock),
        0x337f_9800,
        "one above the cap returns the cap"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(0);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(u64::MAX - 1, clock),
        0x337f_9800,
        "huge difference returns the cap"
    );
    assert_eq!(calls.get(), 1);

    let (clock, calls) = counting_clock(1);
    assert_eq!(
        __std_atomic_wait_get_remaining_timeout(u64::MAX - 1, clock),
        0x337f_9800
    );
    assert_eq!(calls.get(), 1);
}

#[test]
fn remaining_results_never_set_bits_above_bit31() {
    let cases: &[(u64, u64)] = &[
        (u64::MAX, 100),
        (100, 99),
        (0x1000 + 0x337f_9801, 0x1000),
        (u64::MAX - 1, 0),
        (0xf000_0000_0000_0000, 0x8000_0000_0000_0000),
    ];
    for &(deadline, tick) in cases {
        let (clock, _) = counting_clock(tick);
        let result = __std_atomic_wait_get_remaining_timeout(deadline, clock);
        assert_eq!(
            result & 0xffff_ffff_0000_0000,
            0,
            "deadline {deadline:#x} tick {tick:#x} set a bit above bit 31"
        );
    }
}
