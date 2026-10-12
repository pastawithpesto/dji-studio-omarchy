#!/usr/bin/env python3
"""Verify a bounded Qt6QuickDialogs2Utils.dll source map against its PE file."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from typing import Any


EXPECTED_SHA256 = "580d8be7657cd4b074b5d4ee43bc8c325d501aea737ef15c13e41f62bd0da263"
EXPECTED_SIZE = 45240


def fail(message: str) -> None:
    raise ValueError(message)


def parse_pe(data: bytes) -> dict[str, Any]:
    if data[:2] != b"MZ":
        fail("missing DOS signature")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe_offset : pe_offset + 4] != b"PE\0\0":
        fail("missing PE signature")
    machine, section_count, _, _, _, optional_size, _ = struct.unpack_from(
        "<HHIIIHH", data, pe_offset + 4
    )
    optional = pe_offset + 24
    magic = struct.unpack_from("<H", data, optional)[0]
    if magic != 0x20B:
        fail(f"expected PE32+, found optional-header magic {magic:#x}")
    image_base = struct.unpack_from("<Q", data, optional + 24)[0]
    directory_count = struct.unpack_from("<I", data, optional + 108)[0]
    directories = []
    for index in range(min(directory_count, 16)):
        directories.append(struct.unpack_from("<II", data, optional + 112 + index * 8))
    section_offset = optional + optional_size
    sections = []
    for index in range(section_count):
        offset = section_offset + index * 40
        name = data[offset : offset + 8].split(b"\0", 1)[0].decode("ascii")
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
            "<IIII", data, offset + 8
        )
        sections.append(
            {
                "name": name,
                "virtual_size": virtual_size,
                "rva": virtual_address,
                "raw_size": raw_size,
                "raw_offset": raw_offset,
            }
        )

    def rva_to_offset(rva: int, length: int = 1) -> int:
        matches = []
        for section in sections:
            delta = rva - section["rva"]
            if 0 <= delta and delta + length <= section["raw_size"]:
                matches.append(section["raw_offset"] + delta)
        if len(matches) != 1:
            fail(f"RVA {rva:#x} length {length} has {len(matches)} file mappings")
        return matches[0]

    def c_string(rva: int) -> str:
        offset = rva_to_offset(rva)
        end = data.find(b"\0", offset)
        if end < 0:
            fail(f"unterminated PE string at RVA {rva:#x}")
        return data[offset:end].decode("ascii")

    def parse_exports() -> list[dict[str, Any]]:
        if not directories or directories[0] == (0, 0):
            fail("missing PE export directory")
        export_rva, export_size = directories[0]
        export_offset = rva_to_offset(export_rva, 40)
        fields = struct.unpack_from("<IIHHIIIIIII", data, export_offset)
        ordinal_base, function_count, name_count = fields[5], fields[6], fields[7]
        functions_rva, names_rva, ordinals_rva = fields[8], fields[9], fields[10]
        names_by_index: dict[int, str] = {}
        for index in range(name_count):
            name_rva = struct.unpack_from("<I", data, rva_to_offset(names_rva + index * 4, 4))[0]
            ordinal_index = struct.unpack_from(
                "<H", data, rva_to_offset(ordinals_rva + index * 2, 2)
            )[0]
            names_by_index[ordinal_index] = c_string(name_rva)
        exports = []
        for index in range(function_count):
            rva = struct.unpack_from(
                "<I", data, rva_to_offset(functions_rva + index * 4, 4)
            )[0]
            if not rva:
                continue
            exports.append(
                {
                    "name": names_by_index.get(index),
                    "ordinal": ordinal_base + index,
                    "rva": rva,
                    "forwarder": export_rva <= rva < export_rva + export_size,
                }
            )
        return exports

    def parse_runtime_functions() -> tuple[tuple[int, int], list[dict[str, int]]]:
        if len(directories) <= 3 or directories[3] == (0, 0):
            fail("missing PE exception directory")
        exception_rva, exception_size = directories[3]
        if exception_size % 12:
            fail("exception directory size is not a multiple of RUNTIME_FUNCTION size")
        table = rva_to_offset(exception_rva, exception_size)
        rows = []
        for index in range(exception_size // 12):
            begin, end, unwind = struct.unpack_from("<III", data, table + index * 12)
            rows.append({"begin_rva": begin, "end_rva_exclusive": end, "unwind_rva": unwind})
        return (exception_rva, exception_size), rows

    def chained_groups(rows: list[dict[str, int]]) -> dict[tuple[int, int, int], list[tuple[int, int]]]:
        by_tuple = {
            (row["begin_rva"], row["end_rva_exclusive"], row["unwind_rva"]): row
            for row in rows
        }
        children: dict[tuple[int, int, int], list[tuple[int, int]]] = {}
        for row in rows:
            unwind_offset = rva_to_offset(row["unwind_rva"], 4)
            flags = data[unwind_offset] >> 3
            code_count = data[unwind_offset + 2]
            if not flags & 0x4:
                continue
            chained_offset = (4 + code_count * 2 + 3) & ~3
            raw = data[unwind_offset + chained_offset : unwind_offset + chained_offset + 12]
            if len(raw) != 12:
                fail(f"truncated chained UNWIND_INFO at RVA {row['unwind_rva']:#x}")
            parent = struct.unpack("<III", raw)
            if parent not in by_tuple:
                fail(f"chained UNWIND_INFO refers to absent RUNTIME_FUNCTION {parent!r}")
            children.setdefault(parent, []).append((row["begin_rva"], row["end_rva_exclusive"]))
        groups = {}
        for root in children:
            visited: set[tuple[int, int, int]] = set()
            spans: list[tuple[int, int]] = []

            def visit(parent: tuple[int, int, int]) -> None:
                if parent in visited:
                    return
                visited.add(parent)
                row = by_tuple[parent]
                spans.append((row["begin_rva"], row["end_rva_exclusive"]))
                for child_span in children.get(parent, []):
                    child = next(
                        candidate
                        for candidate in rows
                        if candidate["begin_rva"] == child_span[0]
                        and candidate["end_rva_exclusive"] == child_span[1]
                    )
                    child_tuple = (
                        child["begin_rva"],
                        child["end_rva_exclusive"],
                        child["unwind_rva"],
                    )
                    visit(child_tuple)

            visit(root)
            spans.sort()
            groups[root] = spans
        return groups

    return {
        "pe_offset": pe_offset,
        "machine": machine,
        "optional_header_size": optional_size,
        "image_base": image_base,
        "sections": sections,
        "directories": directories,
        "rva_to_offset": rva_to_offset,
        "parse_exports": parse_exports,
        "parse_runtime_functions": parse_runtime_functions,
        "chained_groups": chained_groups,
    }


def verify(
    source_path: Path,
    map_path: Path,
    llvm_export_path: Path | None = None,
    llvm_version: str | None = None,
) -> dict[str, Any]:
    source = source_path.read_bytes()
    mapping = json.loads(map_path.read_text(encoding="utf-8"))
    actual_sha256 = hashlib.sha256(source).hexdigest()
    if len(source) != EXPECTED_SIZE or actual_sha256 != EXPECTED_SHA256:
        fail(
            f"source identity mismatch: size={len(source)} sha256={actual_sha256}"
        )
    declared = mapping["source"]
    if declared["size_bytes"] != len(source) or declared["sha256"] != actual_sha256:
        fail("source map identity does not match the supplied DLL")

    pe = parse_pe(source)
    if pe["image_base"] != int(declared["image_base"], 16):
        fail("image base does not match source map")
    sections = pe["sections"]
    def rva_to_offset(rva: int, length: int) -> int:
        return pe["rva_to_offset"](rva, length)

    parsed_exports = pe["parse_exports"]()
    expected_exports = mapping["export_inventory"]["all_exports"]
    normalize = lambda items: sorted(
        (item["ordinal"], item["rva"], item["name"], item["forwarder"])
        for item in items
    )
    if normalize(parsed_exports) != normalize(expected_exports):
        fail("independently parsed PE exports do not match the source map")
    llvm_check: dict[str, Any] | None = None
    if llvm_export_path:
        llvm_text = llvm_export_path.read_text(encoding="utf-8")
        llvm_exports = []
        for line in llvm_text.splitlines():
            match = re.match(r"\s*(\d+)\s+0x([0-9a-fA-F]+)\s+(.+?)\s*$", line)
            if match:
                llvm_exports.append(
                    {
                        "ordinal": int(match.group(1)),
                        "rva": int(match.group(2), 16),
                        "name": match.group(3),
                        "forwarder": False,
                    }
                )
        if normalize(llvm_exports) != normalize(expected_exports):
            fail("llvm-objdump export rows do not match the PE export directory")
        llvm_check = {
            "tool": "llvm-objdump -p",
            "version": llvm_version or "not supplied",
            "output_sha256": hashlib.sha256(llvm_text.encode("utf-8")).hexdigest(),
            "export_count": len(llvm_exports),
            "matches_pe_parser_and_source_map": True,
        }

    function_results = []
    pseudo_equality_record_count = 0
    for function in mapping["functions"]:
        va = int(function["address_va"], 16)
        rva = va - pe["image_base"]
        body = function["body"]
        start = int(body["range_start_va"], 16)
        end = int(body["range_end_va_inclusive"], 16)
        length = body["byte_count"]
        if start != va or end < start or end - start + 1 != length:
            fail(f"invalid body range for {function['capture_id']}")
        if int(function["rva"], 16) != rva:
            fail(f"RVA mismatch for {function['capture_id']}")
        offset = rva_to_offset(rva, length)
        if offset != body["file_offset"]:
            fail(f"source offset mismatch for {function['capture_id']}")
        saved_bytes = bytes.fromhex(body["bytes_hex"])
        source_bytes = source[offset : offset + length]
        if len(saved_bytes) != length or source_bytes != saved_bytes:
            fail(f"source bytes do not match Ghidra witness for {function['capture_id']}")
        digest = hashlib.sha256(source_bytes).hexdigest()
        if digest != body["sha256"]:
            fail(f"body SHA-256 mismatch for {function['capture_id']}")
        if not body["contiguous"]:
            fail(f"non-contiguous body is outside this source map contract: {function['capture_id']}")
        if function["analysis"]["pseudo_matches_dossier_exactly"]:
            pseudo_equality_record_count += 1
        function_results.append(
            {
                "capture_id": function["capture_id"],
                "address_va": function["address_va"],
                "rva": hex(rva),
                "file_offset": offset,
                "byte_count": length,
                "sha256": digest,
                "original_bytes_equal_ghidra_witness": True,
            }
        )

    data_witness = mapping["metadata_and_strings"]["witness"]
    data_va = int(data_witness["address_va"], 16)
    data_rva = data_va - pe["image_base"]
    data_length = data_witness["length"]
    data_offset = rva_to_offset(data_rva, data_length)
    data_bytes = source[data_offset : data_offset + data_length]
    if data_offset != data_witness["file_offset"]:
        fail("metadata/string data source offset mismatch")
    if data_bytes != bytes.fromhex(data_witness["bytes_hex"]):
        fail("metadata/string bytes do not match Ghidra read_bytes witness")
    if hashlib.sha256(data_bytes).hexdigest() != data_witness["sha256"]:
        fail("metadata/string data SHA-256 mismatch")

    string_results = []
    for string in mapping["metadata_and_strings"]["selected_strings"]:
        offset = int(string["file_offset"], 16)
        raw = bytes.fromhex(string["nul_terminated_bytes_hex"])
        if source[offset : offset + len(raw)] != raw:
            fail(f"selected string bytes do not match at file offset {offset:#x}")
        if not raw.endswith(b"\0"):
            fail(f"selected string is not NUL terminated at file offset {offset:#x}")
        if hashlib.sha256(raw).hexdigest() != string["sha256"]:
            fail(f"selected string hash mismatch at file offset {offset:#x}")
        if not data_offset <= offset or offset + len(raw) > data_offset + data_length:
            fail(f"selected string is outside the captured metadata/string range: {string['text']!r}")
        string_results.append({"text": string["text"], "file_offset": hex(offset), "verified": True})

    (exception_rva, exception_size), runtime_rows = pe["parse_runtime_functions"]()
    if len(runtime_rows) != mapping["runtime_function_chain_evidence"]["runtime_function_record_count"]:
        fail("RUNTIME_FUNCTION row count mismatch")
    chain_groups = pe["chained_groups"](runtime_rows)
    chain_results = []
    for claimed in mapping["runtime_function_chain_evidence"]["selected_function_groups"]:
        root = tuple(int(part, 16) for part in claimed["chain_root"])
        if root not in chain_groups:
            fail(f"missing selected chained unwind group for {claimed['start_va']}")
        spans = chain_groups[root]
        expected_spans = [(int(a, 16), int(b, 16)) for a, b in claimed["spans"]]
        if spans != expected_spans:
            fail(f"UNWIND_INFO chain spans differ for {claimed['start_va']}")
        if any(spans[i][1] != spans[i + 1][0] for i in range(len(spans) - 1)):
            fail(f"UNWIND_INFO fragments are not contiguous for {claimed['start_va']}")
        if spans[0][0] != int(claimed["start"], 16) or spans[-1][1] != int(claimed["end_exclusive"], 16):
            fail(f"UNWIND_INFO union bounds mismatch for {claimed['start_va']}")
        chain_results.append(
            {
                "start_va": claimed["start_va"],
                "fragment_count": len(spans),
                "start_rva": hex(spans[0][0]),
                "end_rva_exclusive": hex(spans[-1][1]),
                "contiguous": True,
                "matches_ghidra_function_body": True,
            }
        )

    set_index = next(
        function for function in mapping["functions"] if function["capture_id"] == "F03"
    )
    code = bytes.fromhex(set_index["body"]["bytes_hex"])
    if code[4:7] != bytes.fromhex("395110"):
        fail("setIndex compare is not the captured 32-bit field compare")
    if code[7] != 0x74:
        fail("setIndex equality branch opcode changed")
    target = 7 + 2 + int.from_bytes(code[8:9], "little", signed=True)
    if code[9:12] != bytes.fromhex("895110"):
        fail("setIndex changed-value store is not the captured 32-bit field store")
    if code[target : target + 5] != bytes.fromhex("4883c438c3"):
        fail("setIndex equality branch does not reach the add/return epilogue")
    static_meta_lea = code[0x1A : 0x21]
    if static_meta_lea[:3] != bytes.fromhex("488d15"):
        fail("setIndex staticMetaObject reference is not the expected RIP-relative LEA")
    static_meta_target = (0x3140 + 0x21) + int.from_bytes(static_meta_lea[3:], "little", signed=True)
    if static_meta_target != 0x57B0:
        fail("setIndex staticMetaObject reference does not resolve to RVA 0x57b0")
    if code[0x32 : 0x38] != bytes.fromhex("ff1500210000"):
        fail("setIndex QMetaObject activation IAT call bytes changed")

    return {
        "status": "PASS",
        "source": {
            "path_argument": str(source_path),
            "size_bytes": len(source),
            "sha256": actual_sha256,
            "image_base": hex(pe["image_base"]),
        },
        "independent_pe_parse": {
            "machine": hex(pe["machine"]),
            "sections": sections,
            "export_count": len(parsed_exports),
            "exports_match_source_map": True,
            "exception_directory_rva": hex(exception_rva),
            "exception_directory_size": hex(exception_size),
            "runtime_function_record_count": len(runtime_rows),
        },
        "llvm_export_check": llvm_check,
        "function_byte_witnesses": {
            "count": len(function_results),
            "body_byte_total": sum(result["byte_count"] for result in function_results),
            "source_matches_ghidra": True,
            "capture_recorded_pseudocode_equality_count": pseudo_equality_record_count,
            "pseudocode_comparison_recomputed_by_this_script": False,
            "functions": function_results,
        },
        "pseudocode_reconciliation": {
            "function_count": len(mapping["functions"]),
            "stored_exact_match_records": pseudo_equality_record_count,
            "raw_text_included_in_source_map": False,
            "method": "Each separate pseudocode result was compared with its dossier pseudocode in the local capture packet. This portable source-byte verifier does not recalculate that text comparison.",
        },
        "metadata_and_strings": {
            "region_address_va": data_witness["address_va"],
            "region_file_offset": data_offset,
            "region_bytes": data_length,
            "source_matches_ghidra": True,
            "selected_strings_verified": len(string_results),
            "strings": string_results,
        },
        "pdata_chain_checks": {
            "selected_groups_verified": len(chain_results),
            "groups": chain_results,
            "source": "PE exception directory and UNWIND_INFO CHAININFO records parsed from the source file",
        },
        "setIndex_finite_branch_check": {
            "compare": "CMP dword ptr [RCX+0x10], EDX",
            "equality_branch_target_offset": target,
            "target_bytes_hex": code[target : target + 5].hex(),
            "changed_value_store": "MOV dword ptr [RCX+0x10], EDX",
            "static_metaobject_rva": hex(static_meta_target),
            "indirect_call_iat_target_va": "0x180005278",
            "details": "The equality branch reaches the epilogue. The unequal branch writes the 32-bit field and reaches the captured activation call path.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="path to the pinned original DLL")
    parser.add_argument("source_map", type=Path, help="path to SOURCE-MAP.json")
    parser.add_argument("--output", type=Path, help="write verification JSON to this path")
    parser.add_argument("--llvm-export-output", type=Path, help="saved output from llvm-objdump -p")
    parser.add_argument("--llvm-version", help="version printed by llvm-objdump --version")
    args = parser.parse_args()
    try:
        result = verify(
            args.source,
            args.source_map,
            args.llvm_export_output,
            args.llvm_version,
        )
    except (OSError, KeyError, TypeError, ValueError, struct.error) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
