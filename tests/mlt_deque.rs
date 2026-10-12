#![allow(clippy::needless_borrow)]

#[path = "../src/mlt/deque.rs"]
pub mod deque;

use deque::*;
use std::collections::{HashMap, HashSet};
use std::ffi::c_void;
use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

const CONTRACT_CASES: &str = include_str!("fixtures/mlt/deque/contract-cases.json");
const ORIGINAL_REFERENCE_CASES: &str = include_str!("fixtures/mlt/deque/original-DEQUE-CASES.json");
const ORIGINAL_REFERENCE_OUTPUT: &str =
    include_str!("fixtures/mlt/deque/original-WINE-DEQUE-FINAL.jsonl");
const REFERENCE_PROVENANCE: &str = include_str!("fixtures/mlt/deque/reference-provenance.json");
const ORIGINAL_EXPORTS: [(&str, &str); 25] = [
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

#[derive(Clone, Debug, Eq, PartialEq)]
enum JsonScalar {
    String(String),
    Integer(i64),
    Boolean(bool),
}

type JsonRecord = HashMap<String, JsonScalar>;

struct FlatJsonReader<'a> {
    bytes: &'a [u8],
    cursor: usize,
}

impl<'a> FlatJsonReader<'a> {
    fn new(input: &'a str) -> Self {
        Self {
            bytes: input.as_bytes(),
            cursor: 0,
        }
    }

    fn whitespace(&mut self) {
        while self
            .bytes
            .get(self.cursor)
            .is_some_and(u8::is_ascii_whitespace)
        {
            self.cursor += 1;
        }
    }

    fn take(&mut self, expected: u8) {
        self.whitespace();
        assert_eq!(self.bytes.get(self.cursor), Some(&expected));
        self.cursor += 1;
    }

    fn string(&mut self) -> String {
        self.take(b'"');
        let mut result = String::new();
        loop {
            let byte = *self
                .bytes
                .get(self.cursor)
                .expect("unterminated JSON string");
            self.cursor += 1;
            match byte {
                b'"' => return result,
                b'\\' => {
                    let escaped = *self
                        .bytes
                        .get(self.cursor)
                        .expect("unterminated JSON escape");
                    self.cursor += 1;
                    match escaped {
                        b'"' => result.push('"'),
                        b'\\' => result.push('\\'),
                        b'/' => result.push('/'),
                        b'b' => result.push('\u{0008}'),
                        b'f' => result.push('\u{000c}'),
                        b'n' => result.push('\n'),
                        b'r' => result.push('\r'),
                        b't' => result.push('\t'),
                        _ => panic!("unsupported escape in flat reference JSON"),
                    }
                }
                0..=0x1f => panic!("control byte in JSON string"),
                _ => result.push(char::from(byte)),
            }
        }
    }

    fn scalar(&mut self) -> JsonScalar {
        self.whitespace();
        match self.bytes.get(self.cursor) {
            Some(b'"') => JsonScalar::String(self.string()),
            Some(b't') if self.bytes.get(self.cursor..self.cursor + 4) == Some(b"true") => {
                self.cursor += 4;
                JsonScalar::Boolean(true)
            }
            Some(b'f') if self.bytes.get(self.cursor..self.cursor + 5) == Some(b"false") => {
                self.cursor += 5;
                JsonScalar::Boolean(false)
            }
            Some(_) => {
                let start = self.cursor;
                while self
                    .bytes
                    .get(self.cursor)
                    .is_some_and(|byte| byte.is_ascii_digit() || *byte == b'-' || *byte == b'+')
                {
                    self.cursor += 1;
                }
                JsonScalar::Integer(
                    std::str::from_utf8(&self.bytes[start..self.cursor])
                        .expect("ASCII JSON integer")
                        .parse()
                        .expect("JSON integer"),
                )
            }
            None => panic!("missing JSON scalar"),
        }
    }

    fn record(&mut self) -> JsonRecord {
        self.take(b'{');
        let mut fields = HashMap::new();
        loop {
            self.whitespace();
            if self.bytes.get(self.cursor) == Some(&b'}') {
                self.cursor += 1;
                return fields;
            }
            let key = self.string();
            self.take(b':');
            assert!(fields.insert(key, self.scalar()).is_none());
            self.whitespace();
            match self.bytes.get(self.cursor) {
                Some(b',') => self.cursor += 1,
                Some(b'}') => {
                    self.cursor += 1;
                    return fields;
                }
                _ => panic!("expected comma or object end in flat JSON"),
            }
        }
    }

    fn records(mut self) -> Vec<JsonRecord> {
        self.whitespace();
        let is_array = self.bytes.get(self.cursor) == Some(&b'[');
        if is_array {
            self.cursor += 1;
        }
        let mut records = Vec::new();
        loop {
            self.whitespace();
            if self.cursor == self.bytes.len()
                || (is_array && self.bytes.get(self.cursor) == Some(&b']'))
            {
                if is_array {
                    self.cursor += 1;
                }
                self.whitespace();
                assert_eq!(self.cursor, self.bytes.len());
                return records;
            }
            records.push(self.record());
            self.whitespace();
            if self.bytes.get(self.cursor) == Some(&b',') {
                assert!(is_array, "JSONL records cannot use array commas");
                self.cursor += 1;
            }
        }
    }
}

fn parse_reference_records(input: &str) -> Vec<JsonRecord> {
    FlatJsonReader::new(input).records()
}

fn field<'a>(record: &'a JsonRecord, name: &str) -> &'a JsonScalar {
    record
        .get(name)
        .unwrap_or_else(|| panic!("missing field {name}"))
}

fn text_field<'a>(record: &'a JsonRecord, name: &str) -> &'a str {
    match field(record, name) {
        JsonScalar::String(value) => value,
        _ => panic!("field {name} is not a string"),
    }
}

fn number_field(record: &JsonRecord, name: &str) -> i64 {
    match field(record, name) {
        JsonScalar::Integer(value) => *value,
        _ => panic!("field {name} is not an integer"),
    }
}

fn bool_field(record: &JsonRecord, name: &str) -> bool {
    match field(record, name) {
        JsonScalar::Boolean(value) => *value,
        _ => panic!("field {name} is not a boolean"),
    }
}

fn bits_field(record: &JsonRecord, name: &str) -> u64 {
    u64::from_str_radix(text_field(record, name).trim_start_matches("0x"), 16).unwrap()
}

fn pointer_bits(value: *mut c_void) -> u64 {
    value as usize as u64
}

fn fixture_pointer(value: i64) -> *mut c_void {
    value as usize as *mut c_void
}

fn assert_fixture_count(deque: Option<&MltDeque>, record: &JsonRecord) {
    assert_eq!(mlt_deque_count(deque), number_field(record, "count") as i32);
}

fn ptr(value: usize) -> *mut c_void {
    value as *mut c_void
}

#[test]
fn static_fixture_pins_all_approved_original_exports() {
    for (name, address) in ORIGINAL_EXPORTS {
        assert!(CONTRACT_CASES.contains(&format!(
            "\"name\": \"{name}\",\n      \"address\": \"{address}\""
        )));
    }
    assert_eq!(ORIGINAL_EXPORTS.len(), 25);
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
    assert_eq!(mlt_deque_insert_at(None, ptr(1), 0).unwrap(), 1);
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
        mlt_deque_insert_at(Some(&mut deque), ptr(10), 0).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), ptr(30), 1).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), ptr(20), 1).unwrap(),
        0
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), ptr(40), -1).unwrap(),
        1
    );
    assert_eq!(
        mlt_deque_insert_at(Some(&mut deque), ptr(40), 4).unwrap(),
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

fn records_for_group<'a>(records: &'a [JsonRecord], group: &str) -> Vec<&'a JsonRecord> {
    records
        .iter()
        .filter(|record| text_field(record, "group") == group)
        .collect()
}

#[test]
fn original_reference_case_json_and_wine_output_match_exactly() {
    let cases = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let output = parse_reference_records(ORIGINAL_REFERENCE_OUTPUT);
    assert_eq!(cases.len(), 481);
    assert_eq!(cases, output);
    let observed_names: HashSet<_> = cases
        .iter()
        .map(|record| text_field(record, "name"))
        .filter(|name| *name != "mlt_deque_insert_comparator")
        .collect();
    let expected_names: HashSet<_> = ORIGINAL_EXPORTS.iter().map(|(name, _)| *name).collect();
    assert_eq!(observed_names, expected_names);
    assert!(
        REFERENCE_PROVENANCE
            .contains("8fa90ecdd9a82cde0f1602e62b6f6c55b2de613d21230c7c108f40e678281509")
    );
    assert!(
        REFERENCE_PROVENANCE
            .contains("5cdc5c19d5690419a53fbb60014f76ac56caf067d383de40a8aa8635a601741e")
    );
    assert!(
        REFERENCE_PROVENANCE
            .contains("59a83da5816e60a196289801f877b2740f9b3f5ff7b22adf638045ea2aa8e05c")
    );
}

#[test]
fn original_null_wrapper_records_match_without_conflating_close_event() {
    let records = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let null_records = records_for_group(&records, "null");
    assert_eq!(null_records.len(), 24);
    for record in null_records {
        let name = text_field(record, "name");
        match name {
            "mlt_deque_count" => {
                assert_eq!(mlt_deque_count(None), number_field(record, "result") as i32);
            }
            "mlt_deque_push_back" => assert_eq!(
                mlt_deque_push_back(None, fixture_pointer(number_field(record, "input"))).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_front" => assert_eq!(
                mlt_deque_push_front(None, fixture_pointer(number_field(record, "input"))).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_back_int" => assert_eq!(
                mlt_deque_push_back_int(None, number_field(record, "input") as i32).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_front_int" => assert_eq!(
                mlt_deque_push_front_int(None, number_field(record, "input") as i32).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_back_double" => {
                assert_eq!(mlt_deque_push_back_double(None, 1.0).unwrap(), 1)
            }
            "mlt_deque_push_front_double" => {
                assert_eq!(mlt_deque_push_front_double(None, 1.0).unwrap(), 1)
            }
            "mlt_deque_peek" => assert_eq!(
                pointer_bits(mlt_deque_peek(None, number_field(record, "index") as i32).unwrap()),
                bits_field(record, "bits")
            ),
            "mlt_deque_peek_back" => assert_eq!(
                pointer_bits(mlt_deque_peek_back(None).unwrap()),
                bits_field(record, "bits")
            ),
            "mlt_deque_peek_front" => assert_eq!(
                pointer_bits(mlt_deque_peek_front(None).unwrap()),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_back" => assert_eq!(
                pointer_bits(mlt_deque_pop_back(None).unwrap()),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_front" => assert_eq!(
                pointer_bits(mlt_deque_pop_front(None).unwrap()),
                bits_field(record, "bits")
            ),
            "mlt_deque_peek_back_int" => assert_eq!(
                mlt_deque_peek_back_int(None).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_peek_front_int" => assert_eq!(
                mlt_deque_peek_front_int(None).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_pop_back_int" => assert_eq!(
                mlt_deque_pop_back_int(None).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_pop_front_int" => assert_eq!(
                mlt_deque_pop_front_int(None).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_peek_back_double" => assert_eq!(
                mlt_deque_peek_back_double(None).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_peek_front_double" => assert_eq!(
                mlt_deque_peek_front_double(None).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_back_double" => assert_eq!(
                mlt_deque_pop_back_double(None).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_front_double" => assert_eq!(
                mlt_deque_pop_front_double(None).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_insert_at" => assert_eq!(
                mlt_deque_insert_at(
                    None,
                    fixture_pointer(number_field(record, "input")),
                    number_field(record, "index") as i32
                )
                .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_remove_at" => assert_eq!(
                mlt_deque_remove_at(None, number_field(record, "index") as i32).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_insert" => assert_eq!(
                mlt_deque_insert::<fn(u64, u64) -> i32>(
                    None,
                    fixture_pointer(number_field(record, "input")),
                    None
                )
                .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_close" => {
                mlt_deque_close(None);
                assert!(bool_field(record, "completed"));
            }
            _ => panic!("unhandled null reference API {name}"),
        }
    }
}

#[test]
fn original_pointer_operation_sequence_matches_each_result_count_and_payload() {
    let records = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let pointer_records = records_for_group(&records, "pointer");
    assert_eq!(pointer_records.len(), 365);
    let mut deque = None;
    for record in pointer_records {
        let name = text_field(record, "name");
        match name {
            "mlt_deque_init" => {
                assert!(bool_field(record, "created"));
                deque = Some(mlt_deque_init().unwrap());
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_push_back" => {
                let value = fixture_pointer(number_field(record, "input"));
                assert_eq!(
                    mlt_deque_push_back(deque.as_mut(), value).unwrap(),
                    number_field(record, "result") as i32
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_push_front" => {
                let value = fixture_pointer(number_field(record, "input"));
                assert_eq!(
                    mlt_deque_push_front(deque.as_mut(), value).unwrap(),
                    number_field(record, "result") as i32
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_peek" => {
                let result =
                    mlt_deque_peek(deque.as_ref(), number_field(record, "index") as i32).unwrap();
                assert_eq!(pointer_bits(result), bits_field(record, "bits"));
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_peek_back" => {
                assert_eq!(
                    pointer_bits(mlt_deque_peek_back(deque.as_ref()).unwrap()),
                    bits_field(record, "bits")
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_peek_front" => {
                assert_eq!(
                    pointer_bits(mlt_deque_peek_front(deque.as_ref()).unwrap()),
                    bits_field(record, "bits")
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_insert_at" => {
                assert_eq!(
                    mlt_deque_insert_at(
                        deque.as_mut(),
                        fixture_pointer(number_field(record, "input")),
                        number_field(record, "index") as i32
                    )
                    .unwrap(),
                    number_field(record, "result") as i32
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_remove_at" => {
                assert_eq!(
                    mlt_deque_remove_at(deque.as_mut(), number_field(record, "index") as i32)
                        .unwrap(),
                    number_field(record, "result") as i32
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_pop_front" => {
                assert_eq!(
                    pointer_bits(mlt_deque_pop_front(deque.as_mut()).unwrap()),
                    bits_field(record, "bits")
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            "mlt_deque_pop_back" => {
                assert_eq!(
                    pointer_bits(mlt_deque_pop_back(deque.as_mut()).unwrap()),
                    bits_field(record, "bits")
                );
                assert_fixture_count(deque.as_ref(), record);
            }
            _ => panic!("unhandled pointer reference API {name}"),
        }
    }
    mlt_deque_close(deque);
}

#[test]
fn original_int_operation_sequence_matches_typed_results_without_upper_slot_reads() {
    let records = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let int_records = records_for_group(&records, "int");
    assert_eq!(int_records.len(), 32);
    let mut deque = mlt_deque_init().unwrap();
    for record in int_records {
        let name = text_field(record, "name");
        match name {
            "mlt_deque_push_back_int" => assert_eq!(
                mlt_deque_push_back_int(Some(&mut deque), number_field(record, "input") as i32)
                    .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_front_int" => assert_eq!(
                mlt_deque_push_front_int(Some(&mut deque), number_field(record, "input") as i32)
                    .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_peek_front_int" => assert_eq!(
                mlt_deque_peek_front_int(Some(&deque)).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_peek_back_int" => assert_eq!(
                mlt_deque_peek_back_int(Some(&deque)).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_pop_front_int" => assert_eq!(
                mlt_deque_pop_front_int(Some(&mut deque)).unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_pop_back_int" => assert_eq!(
                mlt_deque_pop_back_int(Some(&mut deque)).unwrap(),
                number_field(record, "result") as i32
            ),
            _ => panic!("unhandled int reference API {name}"),
        }
        assert_fixture_count(Some(&deque), record);
    }
}

#[test]
fn original_double_operation_sequence_matches_all_eight_result_bits() {
    let records = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let double_records = records_for_group(&records, "double");
    assert_eq!(double_records.len(), 32);
    let values = [0.0, -0.0, 1.0, -1.0, 0.25, 1e300, -1e-300];
    let mut deque = mlt_deque_init().unwrap();
    for record in double_records {
        let name = text_field(record, "name");
        match name {
            "mlt_deque_push_back_double" => assert_eq!(
                mlt_deque_push_back_double(
                    Some(&mut deque),
                    values[number_field(record, "input") as usize]
                )
                .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_push_front_double" => assert_eq!(
                mlt_deque_push_front_double(
                    Some(&mut deque),
                    values[number_field(record, "input") as usize]
                )
                .unwrap(),
                number_field(record, "result") as i32
            ),
            "mlt_deque_peek_front_double" => assert_eq!(
                mlt_deque_peek_front_double(Some(&deque)).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_peek_back_double" => assert_eq!(
                mlt_deque_peek_back_double(Some(&deque)).unwrap().to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_front_double" => assert_eq!(
                mlt_deque_pop_front_double(Some(&mut deque))
                    .unwrap()
                    .to_bits(),
                bits_field(record, "bits")
            ),
            "mlt_deque_pop_back_double" => assert_eq!(
                mlt_deque_pop_back_double(Some(&mut deque))
                    .unwrap()
                    .to_bits(),
                bits_field(record, "bits")
            ),
            _ => panic!("unhandled double reference API {name}"),
        }
        assert_fixture_count(Some(&deque), record);
    }
}

#[test]
fn original_sorted_insert_matches_every_comparator_call_and_final_order() {
    let records = parse_reference_records(ORIGINAL_REFERENCE_CASES);
    let sorted = records_for_group(&records, "sorted");
    assert_eq!(sorted.len(), 28);
    let mut deque = mlt_deque_init().unwrap();
    let mut index = 0usize;
    let mut pending_calls = Vec::new();
    while index < sorted.len() {
        let record = sorted[index];
        let name = text_field(record, "name");
        if name == "mlt_deque_insert_comparator" {
            pending_calls.push((
                bits_field(record, "existing"),
                bits_field(record, "candidate"),
            ));
            index += 1;
            continue;
        }
        if name == "mlt_deque_insert" {
            let expected_calls = std::mem::take(&mut pending_calls);
            let value = fixture_pointer(number_field(record, "input"));
            let status = if number_field(record, "result") == 1 {
                mlt_deque_insert::<fn(u64, u64) -> i32>(Some(&mut deque), value, None).unwrap()
            } else {
                let mut observed_calls = Vec::new();
                let status = mlt_deque_insert(
                    Some(&mut deque),
                    value,
                    Some(|existing: u64, candidate: u64| {
                        observed_calls.push((existing, candidate));
                        match (existing & 0xff).cmp(&(candidate & 0xff)) {
                            std::cmp::Ordering::Less => -1,
                            std::cmp::Ordering::Equal => 0,
                            std::cmp::Ordering::Greater => 1,
                        }
                    }),
                )
                .unwrap();
                assert_eq!(observed_calls, expected_calls);
                status
            };
            assert_eq!(status, number_field(record, "result") as i32);
            assert_fixture_count(Some(&deque), record);
        } else if name == "mlt_deque_peek" {
            let actual =
                mlt_deque_peek(Some(&deque), number_field(record, "index") as i32).unwrap();
            assert_eq!(pointer_bits(actual), bits_field(record, "bits"));
            assert_fixture_count(Some(&deque), record);
        } else {
            panic!("unhandled sorted reference event {name}");
        }
        index += 1;
    }
    assert!(pending_calls.is_empty());
}
