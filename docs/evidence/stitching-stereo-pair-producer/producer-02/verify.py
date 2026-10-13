#!/usr/bin/env python3
"""Check the packet against an original PE file. Do not write to the packet."""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path
from pe_read import PE


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check-saved-dependencies', action='store_true')
    args = parser.parse_args()
    packet = Path(__file__).resolve().parent
    expected = json.loads((packet / 'WITNESSES.json').read_text())
    p = PE(args.source)
    require(p.sha == expected['source']['sha256'], 'Original source hash differs')
    require(len(p.data) == expected['source']['size_bytes'], 'Source size differs')
    require(p.base == int(expected['source']['image_base'], 16), 'Image base differs')
    checked_bytes = 0
    byte_rows = 0
    for capture in expected['captures']:
        path = packet / capture['path']
        require(sha(path) == capture['sha256'], f'Capture hash differs: {path.name}')
        cursor = int(capture['start_va'], 16)
        for line in path.read_text().splitlines():
            match = re.match(r'^\s*([0-9a-f]+):\t([0-9a-f ]+)', line)
            if not match:
                continue
            va = int(match[1], 16)
            raw = bytes.fromhex(match[2])
            require(va == cursor, f'Capture gap or overlap: {path.name} {va:#x}')
            _, original = p.bytes_va(va, len(raw))
            require(raw == original, f'Capture bytes differ: {path.name} {va:#x}')
            cursor += len(raw)
            checked_bytes += len(raw)
            byte_rows += 1
        require(cursor == int(capture['end_va_exclusive'], 16), f'Capture end differs: {path.name}')
    for anchor in expected['anchors']:
        raw = bytes.fromhex(anchor['bytes_hex'])
        off, original = p.bytes_va(int(anchor['va'], 16), len(raw))
        require(off == int(anchor['file_offset'], 16), f'File offset differs: {anchor["label"]}')
        require(raw == original, f'Anchor bytes differ: {anchor["label"]}')
    branches = [
        (0x18019a23a, 0x1801439b0), (0x18019a24c, 0x1801439c0),
        (0x18019a261, 0x18013cd10), (0x18019811c, 0x180134840),
        (0x18013484d, 0x1801476a0), (0x18022864c, 0x18019a1e0),
        (0x180228328, 0x180281760),
    ]
    for va, target in branches:
        _, raw = p.bytes_va(va, 5)
        require(raw[0] == 0xe8, f'Expected CALL rel32 at {va:#x}')
        require(va + 5 + struct.unpack_from('<i', raw, 1)[0] == target, f'Call target differs: {va:#x}')
    rva, size = p.directories[3]
    _, pdata = p.bytes_rva(rva, size)
    for item in expected['pdata']:
        target = int(item['target_va'], 16)
        actual = []
        for i in range(0, len(pdata), 12):
            begin, end, unwind = struct.unpack_from('<III', pdata, i)
            if p.base + begin <= target < p.base + end:
                actual.append({'start_va': hex(p.base + begin), 'end_va_exclusive': hex(p.base + end), 'unwind_rva': hex(unwind)})
        require(actual == item['containing_records'], f'Exception metadata differs: {target:#x}')
    for item in expected['rtti']:
        table = int(item['vtable_va'], 16)
        _, pointer = p.bytes_va(table - 8, 8)
        require(pointer.hex() == item['col_pointer_bytes'], 'RTTI pointer bytes differ')
        col = struct.unpack('<Q', pointer)[0]
        require(col == int(item['col_va'], 16), 'RTTI pointer differs')
        _, raw = p.bytes_va(col, 24)
        require(raw.hex() == item['col_bytes'], 'RTTI descriptor differs')
        sig, offset, cd_offset, type_rva, _, self_rva = struct.unpack('<IIIIII', raw)
        require(sig == 1 and offset == cd_offset == 0 and p.base + self_rva == col, 'RTTI metadata differs')
        require(p.base + type_rva == int(item['type_descriptor_va'], 16), 'RTTI type address differs')
        require(p.cstr_rva(type_rva + 16).decode() == item['type_name'], 'RTTI name differs')
    # This scan finds candidates only. The captured caller corroborates its E8.
    target = 0x18013cd10
    relative = []
    absolute = []
    for section in p.sections:
        raw = p.data[section['raw']:section['raw'] + section['raw_size']]
        for at in range(len(raw) - 4):
            if raw[at] in (0xe8, 0xe9):
                va = p.base + section['rva'] + at
                if va + 5 + struct.unpack_from('<i', raw, at + 1)[0] == target:
                    relative.append(hex(va))
        at = 0
        while (at := raw.find(struct.pack('<Q', target), at)) >= 0:
            absolute.append(hex(p.base + section['rva'] + at))
            at += 1
    require(relative == ['0x18019a261'] and absolute == [], 'Navigation candidate set differs')
    require(not any(x['rva'] == target - p.base for x in p.exports()), 'Target unexpectedly has a named export')
    saved = 0
    if args.check_saved_dependencies:
        for item in expected['saved_dependencies']:
            path = Path(item['path'])
            require(sha(path) == item['sha256'], f'Saved dependency differs: {path}')
            saved += 1
    require(sha(args.source) == p.sha, 'Original source changed during verification')
    return {'result': 'PASS', 'source_sha256': p.sha, 'captures': len(expected['captures']),
            'capture_bytes_checked': checked_bytes, 'capture_byte_rows': byte_rows,
            'fixed_anchors': len(expected['anchors']), 'direct_calls': len(branches),
            'pdata_queries': len(expected['pdata']), 'rtti_records': len(expected['rtti']),
            'saved_dependencies_checked': saved, 'review_status': 'Author validation only; independent review pending',
            'limits': 'Original-file static checks. No new decompilation, vendor execution, live object identity, units, or image parity.'}


if __name__ == '__main__':
    print(json.dumps(main(), indent=2))
