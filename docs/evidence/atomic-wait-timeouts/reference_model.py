"""Static arithmetic model adapted from captured target instructions.

The model accepts synthetic 64-bit time-source values. It never loads the DLL.
Microsoft documents GetTickCount64 as milliseconds; see REPORT.md for the
separate API contract citation. The arithmetic itself follows the target bytes.
"""
MASK64 = (1 << 64) - 1
U64_MAX = MASK64
U32_MAX = (1 << 32) - 1
MAX_REMAINING = 0x337F9800

def get_deadline(timeout_u64: int, tick_count_u64: int) -> int:
    if timeout_u64 == U64_MAX:
        return U64_MAX
    return (tick_count_u64 + timeout_u64) & MASK64

def get_remaining_timeout(deadline_u64: int, tick_count_u64: int) -> int:
    if deadline_u64 == U64_MAX:
        return U32_MAX
    if tick_count_u64 >= deadline_u64:
        return 0
    return min(deadline_u64 - tick_count_u64, MAX_REMAINING)

CASES = [
    {"name": "zero-duration-deadline", "call": "get_deadline", "input": {"timeout_u64": 0, "tick_count_u64": 100}, "expected": "0x64"},
    {"name": "deadline-is-now", "call": "get_remaining_timeout", "input": {"deadline_u64": 100, "tick_count_u64": 100}, "expected": "0x0"},
    {"name": "deadline-in-past", "call": "get_remaining_timeout", "input": {"deadline_u64": 99, "tick_count_u64": 100}, "expected": "0x0"},
    {"name": "one-unit-remaining", "call": "get_remaining_timeout", "input": {"deadline_u64": 101, "tick_count_u64": 100}, "expected": "0x1"},
    {"name": "just-below-cap", "call": "get_remaining_timeout", "input": {"deadline_u64": 864000099, "tick_count_u64": 100}, "expected": "0x337f97ff"},
    {"name": "exact-cap", "call": "get_remaining_timeout", "input": {"deadline_u64": 864000100, "tick_count_u64": 100}, "expected": "0x337f9800"},
    {"name": "above-cap", "call": "get_remaining_timeout", "input": {"deadline_u64": 864000101, "tick_count_u64": 100}, "expected": "0x337f9800"},
    {"name": "infinite-timeout-input", "call": "get_deadline", "input": {"timeout_u64": U64_MAX, "tick_count_u64": 100}, "expected": "0xffffffffffffffff"},
    {"name": "infinite-deadline-is-32-bit-infinite", "call": "get_remaining_timeout", "input": {"deadline_u64": U64_MAX, "tick_count_u64": 100}, "expected": "0xffffffff"},
    {"name": "finite-addition-collides-with-infinite-sentinel", "call": "get_deadline", "input": {"timeout_u64": 10, "tick_count_u64": U64_MAX - 10}, "expected": "0xffffffffffffffff"},
    {"name": "finite-addition-wraps-to-zero", "call": "get_deadline", "input": {"timeout_u64": 11, "tick_count_u64": U64_MAX - 10}, "expected": "0x0"},
]

for case in CASES:
    actual = globals()[case["call"]](**case["input"])
    assert actual == int(case["expected"], 16), (case["name"], actual, case["expected"])
print("PASS:", len(CASES), "static arithmetic cases")
for case in CASES:
    value = globals()[case["call"]](**case["input"])
    print(case["name"] + " -> " + f"0x{value:x}")
