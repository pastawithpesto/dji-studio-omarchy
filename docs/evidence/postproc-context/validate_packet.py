#!/usr/bin/env python3
"""Independently validate the bounded postproc-58 evidence packet against a supplied DLL."""
from __future__ import annotations

import hashlib
import json
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

EXPECTED_SHA256 = 'fcb300de9e4702545991c4487e0ee90728090f22f3639c4bf6adc0bd4a03617b'
EXPECTED_SIZE = 99512
EXPECTED_EXPORTS = {
    'postproc_configuration': (1, 0x102D),
    'postproc_ffversion': (2, 0x12B78),
    'postproc_license': (3, 0x119A),
    'postproc_version': (4, 0x1019),
    'pp_free_context': (5, 0x1082),
    'pp_free_mode': (6, 0x10F5),
    'pp_get_context': (7, 0x1087),
    'pp_get_mode_by_name_and_quality': (8, 0x1190),
    'pp_help': (9, 0x118E0),
    'pp_postprocess': (10, 0x11AE),
}
IMPLEMENTATION_TARGETS = {
    'postproc_version': 0x18000B930,
    'postproc_configuration': 0x18000B910,
    'postproc_license': 0x18000B920,
    'pp_free_context': 0x180009340,
    'pp_get_context': 0x180009450,
}

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)

def parse_pe(data: bytes):
    require(data[:2] == b'MZ', 'Missing DOS signature')
    peoff = struct.unpack_from('<I', data, 0x3C)[0]
    require(data[peoff:peoff + 4] == b'PE\0\0', 'Missing PE signature')
    coff = peoff + 4
    machine, section_count, _, _, _, optional_size, _ = struct.unpack_from('<HHIIIHH', data, coff)
    optional = coff + 20
    magic = struct.unpack_from('<H', data, optional)[0]
    require(magic == 0x20B, f'Expected PE32+, found optional magic {magic:#x}')
    image_base = struct.unpack_from('<Q', data, optional + 24)[0]
    export_rva, export_size = struct.unpack_from('<II', data, optional + 112)
    section_table = optional + optional_size
    sections = []
    for index in range(section_count):
        p = section_table + index * 40
        name = data[p:p + 8].split(b'\0', 1)[0].decode('ascii')
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from('<IIII', data, p + 8)
        sections.append((name, virtual_address, virtual_size, raw_offset, raw_size))

    def rva_to_offset(rva: int, length: int = 1) -> int:
        for _, va, virtual_size, raw, raw_size in sections:
            if va <= rva and rva + length <= va + raw_size and rva + length <= va + max(virtual_size, raw_size):
                return raw + rva - va
        raise ValueError(f'RVA range is not fully file backed: {rva:#x}+{length:#x}')

    export_off = rva_to_offset(export_rva, 40)
    ordinal_base, function_count, name_count = struct.unpack_from('<III', data, export_off + 16)
    functions_rva, names_rva, ordinals_rva = struct.unpack_from('<III', data, export_off + 28)
    names_off = rva_to_offset(names_rva, name_count * 4)
    ordinals_off = rva_to_offset(ordinals_rva, name_count * 2)
    exports = {}
    for i in range(name_count):
        name_rva = struct.unpack_from('<I', data, names_off + 4 * i)[0]
        name_off = rva_to_offset(name_rva)
        name_end = data.index(b'\0', name_off)
        name = data[name_off:name_end].decode('ascii')
        func_index = struct.unpack_from('<H', data, ordinals_off + 2 * i)[0]
        func_rva = struct.unpack_from('<I', data, rva_to_offset(functions_rva + 4 * func_index, 4))[0]
        exports[name] = (ordinal_base + func_index, func_rva)
    return machine, magic, image_base, sections, exports, rva_to_offset

def rip_target(address: int, instruction: bytes, opcode: bytes) -> int:
    require(instruction.startswith(opcode) and instruction[-1] == 0xC3, f'Expected LEA/RET bytes at {address:#x}')
    displacement = struct.unpack_from('<i', instruction, len(opcode))[0]
    return address + len(opcode) + 4 + displacement

def cstring(data: bytes, offset: int):
    end = data.index(b'\0', offset)
    return data[offset:end], end

def run(binary_path: Path, map_path: Path):
    data = binary_path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    require(len(data) == EXPECTED_SIZE, f'Source size changed: {len(data)}')
    require(digest == EXPECTED_SHA256, f'Source SHA-256 changed: {digest}')
    machine, magic, image_base, sections, exports, rva_to_offset = parse_pe(data)
    require(machine == 0x8664 and magic == 0x20B, 'Unexpected PE machine or optional-header format')
    require(exports == EXPECTED_EXPORTS, f'Export table changed: {exports!r}')
    source_map = json.loads(map_path.read_text())
    require(source_map['artifact']['sha256'] == digest, 'Source map has a different SHA-256')
    require(source_map['artifact']['size_bytes'] == len(data), 'Source map has a different size')
    require(len(source_map['exports']) == len(EXPECTED_EXPORTS), 'Source map export inventory is incomplete')
    require({row['name'] for row in source_map['exports']} == set(EXPECTED_EXPORTS), 'Source map export names are incomplete or duplicated')
    for row in source_map['exports']:
        name = row['name']
        ordinal, rva = EXPECTED_EXPORTS[name]
        require((row['ordinal'], int(row['rva'], 16)) == (ordinal, rva), f'Export inventory mismatch: {name}')
        require(row['ghidra_name_count'] == 1 and row['ghidra_address_matches_llvm'], f'Ghidra export name/address mismatch: {name}')

    byte_checks = []
    target_blobs = {}
    for name, target_expected in IMPLEMENTATION_TARGETS.items():
        record = source_map['selected_exports'][name]
        export_va = image_base + int(record['export_rva'], 16)
        export_offset = rva_to_offset(int(record['export_rva'], 16), 5)
        stub = data[export_offset:export_offset + 5]
        require(stub[0] == 0xE9, f'{name} export is not an x86-64 rel32 JMP')
        target = export_va + 5 + struct.unpack_from('<i', stub, 1)[0]
        require(target == target_expected, f'{name} thunk target mismatch: {target:#x}')
        imp = record['implementation']
        body = imp['body']
        body_range = body['ranges'][0]
        body_va = int(body_range['start'], 16)
        body_len = int(body['total_bytes'])
        body_off = rva_to_offset(body_va - image_base, body_len)
        actual = data[body_off:body_off + body_len]
        require(actual.hex() == imp['body_bytes_hex'], f'{name} implementation bytes differ from source-map witness')
        require(hashlib.sha256(actual).hexdigest() == imp['body_sha256'], f'{name} body digest mismatch')
        require(int(imp['independent_file_offset']) == body_off, f'{name} PE source offset mismatch')
        require(imp['provider_bytes_match_source'], f'{name} provider/source witness was not exact')
        target_blobs[name] = (body_va, actual)
        byte_checks.append({'name': name, 'export_stub': 'match', 'target': hex(target), 'body_length': body_len, 'body_sha256': imp['body_sha256'], 'provider_equals_source': True})

    vaddr, version = target_blobs['postproc_version']
    require(version == bytes.fromhex('b864013a00c3'), 'postproc_version immediate/RET bytes changed')
    version_value = struct.unpack_from('<I', version, 1)[0]
    require(version_value == 0x3A0164, 'postproc_version immediate mismatch')

    string_checks = []
    for name, expected_text in [
        ('postproc_configuration', source_map['selected_exports']['postproc_configuration']['returned_static_string']['value_ascii']),
        ('postproc_license', 'nonfree and unredistributable'),
    ]:
        function_va, code = target_blobs[name]
        data_va = rip_target(function_va, code, bytes.fromhex('488d05'))
        recorded = source_map['selected_exports'][name]['returned_static_string']
        require(data_va == int(recorded['va'], 16), f'{name} RIP-relative pointer mismatch')
        offset = rva_to_offset(data_va - image_base)
        value, nul = cstring(data, offset)
        require(value.decode('ascii') == expected_text, f'{name} returned C string mismatch')
        require(nul - offset == recorded['length_excluding_nul'], f'{name} string length mismatch')
        require(hashlib.sha256(value).hexdigest() == recorded['sha256_excluding_nul'], f'{name} string digest mismatch')
        string_checks.append({'name': name, 'va': hex(data_va), 'length_excluding_nul': len(value), 'sha256': hashlib.sha256(value).hexdigest(), 'exact': True})

    ff = source_map['selected_exports']['postproc_ffversion']
    ff_value, ff_nul = cstring(data, int(ff['file_offset'], 16))
    require(ff_value.decode('ascii') == 'FFmpeg version 7.0.2', 'postproc_ffversion data string mismatch')
    require(ff_nul == int(ff['value']['nul_terminator_file_offset'], 16), 'postproc_ffversion NUL offset mismatch')
    string_checks.append({'name': 'postproc_ffversion', 'va': ff['va'], 'length_excluding_nul': len(ff_value), 'sha256': hashlib.sha256(ff_value).hexdigest(), 'exact': True})

    get_va, get_ctx = target_blobs['pp_get_context']
    require(bytes.fromhex('b960050000') in get_ctx, 'pp_get_context 0x560 allocation-size immediate is absent')
    require(bytes.fromhex('4885db750733c0e980000000') in get_ctx, 'pp_get_context allocation-result check/null return path is absent')
    require(bytes.fromhex('898324050000') in get_ctx and bytes.fromhex('898b20050000') in get_ctx, 'pp_get_context mode-field stores are absent')
    require(bytes.fromhex('418d460f8bf09983e20f83e6f08d2c02c1fd0483c502') in get_ctx, 'pp_get_context 32-bit width arithmetic changed')
    require(bytes.fromhex('40f6c708740f8bcf8bc783e103c1f80483e003eb04') in get_ctx, 'pp_get_context bit-3 mode branch changed')
    require(bytes.fromhex('0fbae713') in get_ctx and bytes.fromhex('e875240000eb17') in get_ctx and bytes.fromhex('0fbae71c') in get_ctx and bytes.fromhex('0f42c2') in get_ctx, 'pp_get_context CPU flag branches changed')
    require(bytes.fromhex('c78310050000ffffffff') in get_ctx, 'pp_get_context +0x510 sentinel store is absent')
    require(bytes.fromhex('448bce898314050000458bc7896c2420418bd6488bcb') in get_ctx, 'pp_get_context initializer arguments changed')
    helper_call = get_va + 0xBE
    call_off = helper_call - get_va
    require(get_ctx[call_off] == 0xE8, 'pp_get_context helper call instruction is absent')
    helper_target = helper_call + 5 + struct.unpack_from('<i', get_ctx, call_off + 1)[0]
    require(helper_target == 0x18000A970, 'pp_get_context initializer target mismatch')
    malloc_call = get_va + 0x26
    malloc_off = malloc_call - get_va
    require(get_ctx[malloc_off] == 0xE8 and malloc_call + 5 + struct.unpack_from('<i', get_ctx, malloc_off + 1)[0] == 0x18000B93C, 'pp_get_context allocation wrapper target mismatch')
    cpu_call = get_va + 0x8A
    cpu_off = cpu_call - get_va
    require(get_ctx[cpu_off] == 0xE8 and cpu_call + 5 + struct.unpack_from('<i', get_ctx, cpu_off + 1)[0] == 0x18000B954, 'pp_get_context CPU-feature wrapper target mismatch')

    # Evaluate the observed 32-bit arithmetic and bit tests for finite examples.
    def signed32(value: int) -> int:
        value &= 0xFFFFFFFF
        return value - 0x100000000 if value & 0x80000000 else value

    def width_args(width: int):
        wrapped = (width + 15) & 0xFFFFFFFF
        sign_correction = 0xF if wrapped & 0x80000000 else 0
        rounded = signed32(wrapped + sign_correction)
        return {'input': width, 'aligned': wrapped & 0xFFFFFFF0, 'helper_dimension': (rounded >> 4) + 2}

    dimension_vectors = [width_args(width) for width in [0, 1, 15, 16, 17, 31, 32, 33]]
    require([x['aligned'] for x in dimension_vectors] == [0, 16, 16, 16, 32, 32, 32, 48], 'Finite aligned-width oracle failed')
    require([x['helper_dimension'] for x in dimension_vectors] == [2, 3, 3, 3, 4, 4, 4, 5], 'Finite helper-dimension oracle failed')

    def flags(config: int):
        if config & 8:
            field_520, field_524 = config & 3, (config >> 4) & 3
        else:
            field_520 = field_524 = 1
        cpu = 'av_get_cpu_flags()' if config & (1 << 19) else (1 if config & (1 << 28) else 0)
        return field_520, field_524, cpu

    flag_vectors = [
        {'input': 0x00000000, 'expected': (1, 1, 0)},
        {'input': 0x00000008, 'expected': (0, 0, 0)},
        {'input': 0x00000029, 'expected': (1, 2, 0)},
        {'input': 0x0000003B, 'expected': (3, 3, 0)},
        {'input': 0x10000000, 'expected': (1, 1, 1)},
        {'input': 0x00080000, 'expected': (1, 1, 'av_get_cpu_flags()')},
    ]
    for vector in flag_vectors:
        require(flags(vector['input']) == vector['expected'], f"Configuration flag vector failed: {vector['input']:#x}")
    free_va, free_blob = target_blobs['pp_free_context']
    require(free_blob.startswith(bytes.fromhex('48 89 5c 24 08 48 89 6c 24 10 48 89 74 24 18 57 48 83 ec 20 33 db 48 8d 71 28 8b fb 48 8b e9 90 48 8b 0e')), 'Free path first context load or pre-load null-guard boundary changed')
    require(bytes.fromhex('48 8b 0e e8 da 25 00 00 ff c7 48 8d 76 08 83 ff 03 72 ed') in free_blob, 'Free path first three-slot pointer loop changed')
    require(bytes.fromhex('48 8d 7d 40 48 8b 0f e8 c3 25 00 00 ff c3 48 8d 7f 08 83 fb 03 72 ed') in free_blob, 'Free path second three-slot pointer loop changed')
    scalar_loads = [bytes.fromhex(x) for x in [
        '48 8b 4d 08', '48 8b 4d 10', '48 8b 4d 58', '48 8b 4d 60', '48 8b 4d 68',
        '48 8b 8d c0 04 00 00', '48 8b 8d c8 04 00 00', '48 8b 8d d0 04 00 00',
    ]]
    require(all(insn in free_blob for insn in scalar_loads), 'Free path scalar pointer offsets changed')
    require(bytes.fromhex('33 d2 41 b8 60 05 00 00 48 8b cd') in free_blob, 'Free path memset arguments changed')
    free_call_sites = [0x180009363, 0x18000937A, 0x18000938E, 0x180009397, 0x1800093A0, 0x1800093A9, 0x1800093B2, 0x1800093BE, 0x1800093CA, 0x1800093D6]
    free_call_targets = []
    for call_va in free_call_sites:
        offset = call_va - free_va
        require(free_blob[offset] == 0xE8, f'Expected av_free call at {call_va:#x}')
        free_call_targets.append(call_va + 5 + struct.unpack_from('<i', free_blob, offset + 1)[0])
    require(free_call_targets == [0x18000B942] * 10, 'Static av_free call sites changed')
    memset_va = 0x1800093E6
    memset_offset = memset_va - free_va
    require(free_blob[memset_offset] == 0xE8 and memset_va + 5 + struct.unpack_from('<i', free_blob, memset_offset + 1)[0] == 0x18000D2A8, 'Free path memset target mismatch')
    require(free_blob[-5] == 0xE9, 'Free path expected tail jump to av_free')
    free_tail_va = 0x180009402
    free_tail_target = free_tail_va + 5 + struct.unpack_from('<i', free_blob, len(free_blob) - 4)[0]
    require(free_tail_target == 0x18000B942, 'Free path tail target mismatch')

    return {
        'status': 'pass',
        'validated_at_utc': datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        'binary': {'path_argument': str(binary_path), 'size_bytes': len(data), 'sha256': digest, 'machine': hex(machine), 'pe32_plus': magic == 0x20B, 'export_count': len(exports)},
        'export_comparison': {'llvm_pe_parser_vs_source_map': 'all 10 exact names, ordinals, and RVAs match', 'ghidra': 'each export name appears exactly once at its matching VA'},
        'body_witnesses': byte_checks,
        'identity_checks': {'postproc_version_hex': hex(version_value), 'postproc_version_decimal': version_value, 'strings': string_checks},
        'context_checks': {
            'requested_allocation_bytes': 0x560,
            'allocation_failure_branch_returns_null': True,
            'initializer_call_target': hex(helper_target),
            'width_formula_vectors': dimension_vectors,
            'configuration_flag_vectors': [{'input': hex(v['input']), 'fields_0x520_0x524_cpu': list(v['expected'])} for v in flag_vectors],
            'free_member_pointer_fields': {'first_loop': {'start': '0x28', 'count': 3, 'stride': 8}, 'second_loop': {'start': '0x40', 'count': 3, 'stride': 8}, 'single_fields': ['0x08', '0x10', '0x58', '0x60', '0x68', '0x4c0', '0x4c8', '0x4d0']},
            'free_member_pointer_count': 14,
            'static_av_free_call_instructions': 10,
            'zero_context_bytes_before_final_free': 0x560,
            'final_av_free_tail_target': hex(free_tail_target),
            'null_context_guard_observed': False,
            'dll_executed': False,
        },
        'limits': [
            'The finite vectors test a direct transcription of captured x86-64 arithmetic; they do not execute the DLL.',
            'The initializer at 0x18000a970 and AVUTIL/VCRUNTIME implementations are outside this packet.',
            'Context field roles, source-level types, caller obligations, and pointer alias behavior remain unknown.',
        ],
    }

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: validate_packet.py /path/to/postproc-58.dll source-map.json')
    result = run(Path(sys.argv[1]), Path(sys.argv[2]))
    print(json.dumps(result, indent=2))
