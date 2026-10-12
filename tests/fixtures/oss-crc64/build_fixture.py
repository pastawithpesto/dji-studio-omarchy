#!/usr/bin/env python3
"""Create and finalize a bounded corpus for the original DLL harness."""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CASES = HERE / "cases.tsv"
OBSERVED = HERE / "observed.tsv"
FIXTURE = HERE / "ORIGINAL-EXPORT-FIXTURE.json"
POLY = 0xC96C5795D7870F42
SEEDS = [0, 1, 0xFFFFFFFFFFFFFFFF, 0x0123456789ABCDEF,
         0x8000000000000000, POLY]


def pattern_bytes(name: str, length: int) -> bytes:
    if name == "zero":
        return bytes(length)
    if name == "ones":
        return bytes([0xFF]) * length
    if name == "ramp":
        return bytes(i & 0xFF for i in range(length))
    if name == "high":
        return bytes(0xFF if i & 1 else 0x80 for i in range(length))
    if name == "msg":
        m = b"123456789"
        return bytes(m[i % len(m)] for i in range(length))
    if name == "pattern":
        return bytes((i * 37 + (i >> 3) * 11 + 0x80) & 0xFF for i in range(length))
    if name.startswith("tail"):
        start = int(name[4:])
        return bytes(((i + start) * 37 + ((i + start) >> 3) * 11 + 0x80) & 0xFF
                     for i in range(length))
    raise ValueError(name)


def u64(n: int) -> str:
    return f"0x{n & 0xffffffffffffffff:016x}"


rows = []
compute_inputs = {}
combine_inputs = {}


def add_compute(label, seed, pattern, offset, length, group):
    cid = f"C{len(compute_inputs):05d}"
    rec = {"id": cid, "group": group, "seed": u64(seed), "pattern": pattern,
           "offset": offset, "length": length}
    rec["data_sha256"] = hashlib.sha256(pattern_bytes(pattern, length)).hexdigest()
    compute_inputs[cid] = rec
    rows.append("\t".join(["C", cid, u64(seed), pattern, str(offset), str(length)]))
    return cid


def add_combine(label, crc1, crc2, length2, group):
    cid = f"B{len(combine_inputs):05d}"
    rec = {"id": cid, "group": group, "crc1": u64(crc1), "crc2": u64(crc2),
           "length2": u64(length2)}
    combine_inputs[cid] = rec
    rows.append("\t".join(["B", cid, u64(crc1), u64(crc2), u64(length2)]))
    return cid


def prepare():
    # Every small byte length exercises each byte alignment and five full-width seeds.
    short_seeds = SEEDS[:5]
    for length in range(18):
        for pattern in ["zero", "ramp", "high"]:
            for seed in short_seeds:
                for offset in range(8):
                    add_compute(f"small/{length}/{pattern}/{seed}/{offset}",
                                seed, pattern, offset, length, "alignment_and_length")
    # Selected values straddle byte, qword, and wider bulk boundaries.
    for length in [31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256,
                   257, 1024, 1025, 4096, 4097]:
        for pattern in ["ramp", "high"]:
            for seed in SEEDS[:3]:
                for offset in range(8):
                    add_compute(f"boundary/{length}/{pattern}/{seed}/{offset}",
                                seed, pattern, offset, length, "alignment_and_length")

    # Wider inputs remain bounded while exercising bulk and tail paths.
    for pattern in ["zero", "ramp", "high"]:
        for seed in SEEDS[:3]:
            for offset in [0, 3, 7]:
                add_compute("wide/65537", seed, pattern, offset, 65537, "wide_input")
    for offset in range(8):
        add_compute("wide/1048576", 0x8000000000000000, "pattern", offset,
                    1048576, "wide_input")

    # Full byte alphabet, the published 123456789 vector, and incremental partitions.
    for seed in SEEDS[:5]:
        add_compute("all_byte_values", seed, "ramp", 5, 256, "byte_alphabet")
        add_compute("123456789", seed, "msg", 2, 9, "message_vector")
    for seed in SEEDS[:3]:
        for split in [0, 1, 7, 8, 9, 511, 1024, 2048, 3073, 4087, 4095, 4096]:
            add_compute(f"incremental/prefix/{split}", seed, "pattern", 3, split,
                        "incremental_parts")
            add_compute(f"incremental/suffix/{split}", 0, f"tail{split}", 3 + split,
                        4096 - split, "incremental_parts")
            add_compute(f"incremental/whole/{split}", seed, "pattern", 3, 4096,
                        "incremental_parts")

    # Arbitrary CRC words exercise all input bits independently from Compute.
    words = [0, 1, 0xFFFFFFFFFFFFFFFF, 0x0123456789ABCDEF,
             0x8000000000000000, POLY]
    lengths2 = [0, 1, 2, 7, 8, 9, 15, 16, 17, 0x7FFFFFFF, 0x80000000,
                0xFFFFFFFF, 0x100000000, 0x7FFFFFFFFFFFFFFF,
                0x8000000000000000, 0xFFFFFFFFFFFFFFFF]
    for length2 in lengths2:
        for crc1 in words:
            for crc2 in words:
                add_combine("full_width_arbitrary", crc1, crc2, length2,
                            "combine_full_width")

    # Valid joins compare direct seeded computation with CombineCRC64.
    joins = []
    for seed in SEEDS[:4]:
        for length, split in [(0, 0), (1, 0), (9, 1), (17, 8),
                              (257, 127), (4096, 2048)]:
            prefix = add_compute("join/prefix", seed, "pattern", 1, split, "valid_join")
            suffix = add_compute("join/suffix", 0, f"tail{split}", 1 + split,
                                 length - split, "valid_join")
            whole = add_compute("join/whole", seed, "pattern", 1, length, "valid_join")
            joins.append({"seed": u64(seed), "length": length, "split": split,
                          "prefix_id": prefix, "suffix_id": suffix, "whole_id": whole})

    CASES.write_text("\n".join(rows) + "\n", encoding="ascii")
    (HERE / "input-manifest.json").write_text(json.dumps({
        "description": "UTF-8 TSV input descriptors. Data bytes follow named deterministic patterns.",
        "case_count": len(rows), "compute_case_count": len(compute_inputs),
        "combine_case_count": len(combine_inputs), "compute": compute_inputs,
        "combine": combine_inputs, "valid_joins": joins,
        "patterns": {
            "zero": "all zero bytes",
            "ones": "all 0xff bytes",
            "ramp": "byte i = i modulo 256",
            "high": "alternating 0x80, 0xff starting with 0x80",
            "msg": "repeated ASCII bytes 123456789",
            "pattern": "byte i = (37*i + 11*(i >> 3) + 0x80) modulo 256",
            "tailN": "pattern bytes beginning at source index N; used for suffixes in segmented inputs"
        }
    }, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(rows)} cases ({len(compute_inputs)} compute, {len(combine_inputs)} combine)")


def finalize():
    inputs = json.loads((HERE / "input-manifest.json").read_text(encoding="utf-8"))
    observed_lines = OBSERVED.read_text(encoding="ascii").splitlines()
    observed_lines += (HERE / "join-observed.tsv").read_text(encoding="ascii").splitlines()
    if len(observed_lines) != inputs["case_count"]:
        raise SystemExit(f"observed line count mismatch: {len(observed_lines)} != {inputs['case_count']}")
    results = {}
    for line in observed_lines:
        fields = line.split("\t")
        if fields[0] == "C" and len(fields) == 7:
            _, cid, seed, pattern, offset, length, result = fields
            expected = inputs["compute"][cid]
            identity = (int(seed, 16), pattern, int(offset), int(length))
            wanted = (int(expected["seed"], 16), expected["pattern"], expected["offset"], expected["length"])
            if identity != wanted:
                raise SystemExit(f"compute echo mismatch: {cid}")
            results[cid] = {**expected, "expected_result": result.lower()}
        elif fields[0] == "B" and len(fields) == 6:
            _, cid, crc1, crc2, length2, result = fields
            expected = inputs["combine"][cid]
            identity = (int(crc1, 16), int(crc2, 16), int(length2, 16))
            wanted = (int(expected["crc1"], 16), int(expected["crc2"], 16), int(expected["length2"], 16))
            if identity != wanted:
                raise SystemExit(f"combine echo mismatch: {cid}")
            results[cid] = {**expected, "expected_result": result.lower()}
        else:
            raise SystemExit(f"unexpected output row: {line!r}")
    if len(results) != inputs["case_count"]:
        raise SystemExit("duplicate or missing IDs in observed result")
    by_id = results
    failed_joins = []
    for join in inputs["valid_joins"]:
        prefix = int(by_id[join["prefix_id"]]["expected_result"], 16)
        suffix = int(by_id[join["suffix_id"]]["expected_result"], 16)
        whole = by_id[join["whole_id"]]["expected_result"]
        combined = by_id[join["combine_id"]]["expected_result"]
        if combined != whole:
            failed_joins.append(join)
    fixture = {
        "evidence_kind": "observed_original_export_results_under_wine",
        "reference_build": "DJI Studio 1.0.0.30839",
        "source": {
            "path": "/home/violence/Projects/dji-studio-omarchy/extracted/1.0.0.30839/alibabacloud-oss-cpp-sdk.dll",
            "sha256": "083397c9bfadbb1afbea296fa8a3e15403e147aebdb842d8ae55e614794891a1",
            "bytes": 3130552
        },
        "execution": {
            "platform": "Linux x86_64, Wine 11.17, isolated per-task prefix",
            "native_windows_parity_claimed": False,
            "harness": "original_exports.c; dynamically resolves only the two named exports",
            "call_limits": "Safe allocated input buffers and valid scalar values only. No SDK or network operations."
        },
        "corpus": {
            "case_count": inputs["case_count"],
            "compute": [results[cid] for cid in inputs["compute"]],
            "combine": [results[cid] for cid in inputs["combine"]],
            "valid_joins": inputs["valid_joins"],
            "input_patterns": inputs["patterns"]
        },
        "checks": {
            "all_cases_observed": len(results) == inputs["case_count"],
            "valid_join_semantics": "For each join, CombineCRC64(ComputeCRC64(seed,prefix), ComputeCRC64(0,suffix), suffix_length) equals direct ComputeCRC64(seed,whole).",
            "valid_join_count": len(inputs["valid_joins"]),
            "unresolved_join_mismatches": failed_joins
        }
    }
    FIXTURE.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
    print(f"finalized {len(results)} results to {FIXTURE}")


def extend_joins():
    inputs = json.loads((HERE / "input-manifest.json").read_text(encoding="utf-8"))
    observed = {}
    for line in OBSERVED.read_text(encoding="ascii").splitlines():
        fields = line.split("\t")
        if fields[0] == "C" and len(fields) == 7:
            observed[fields[1]] = int(fields[6], 16)
    join_rows = []
    for join in inputs["valid_joins"]:
        crc1 = observed[join["prefix_id"]]
        crc2 = observed[join["suffix_id"]]
        length2 = join["length"] - join["split"]
        cid = f"B{len(inputs['combine']):05d}"
        inputs["combine"][cid] = {
            "id": cid, "group": "valid_join", "crc1": u64(crc1),
            "crc2": u64(crc2), "length2": u64(length2)
        }
        join["combine_id"] = cid
        join_rows.append("\t".join(["B", cid, u64(crc1), u64(crc2), u64(length2)]))
    (HERE / "join-cases.tsv").write_text("\n".join(join_rows) + "\n", encoding="ascii")
    (HERE / "join-observed.tsv").write_text("", encoding="ascii")
    inputs["valid_join_combine_count"] = len(join_rows)
    inputs["case_count"] += len(join_rows)
    inputs["combine_case_count"] += len(join_rows)
    (HERE / "input-manifest.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(join_rows)} original-export join cases")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"prepare", "extend-joins", "finalize"}:
        raise SystemExit("usage: build_fixture.py prepare|extend-joins|finalize")
    {"prepare": prepare, "extend-joins": extend_joins, "finalize": finalize}[sys.argv[1]]()
