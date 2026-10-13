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
    parser.add_argument('--prior-packet', type=Path)
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
    branches = expected['branches']
    for item in branches:
        va, target = int(item['va'], 16), int(item['target'], 16)
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
    original_imports = p.imports()
    for item in expected['imports']:
        va = int(item['thunk_va'], 16)
        _, raw = p.bytes_va(va, 6)
        require(raw.hex() == item['thunk_bytes'] and raw[:2] == b'\xff\x25', 'Import thunk differs')
        iat = va + 6 + struct.unpack_from('<i', raw, 2)[0]
        require(iat == int(item['iat_va'], 16), 'IAT target differs')
        found = [(m['dll'], s['symbol']) for m in original_imports for s in m['symbols'] if int(s['iat_va'], 16) == iat]
        require(found == [(item['dll'], item['symbol'])], 'Import identity differs')
    for item in expected['strings']:
        require(p.cstr_rva(int(item['va'], 16) - p.base).decode() == item['text'], 'Original string differs')
    prior = args.prior_packet or packet.parent / 'producer-02'
    require(sha(prior / 'MANIFEST.json') == expected['prior_packet']['sha256'], 'Prior packet seal differs')
    prior_manifest = json.loads((prior / 'MANIFEST.json').read_text())
    for name, pin in prior_manifest['files'].items():
        require(sha(prior / name) == pin['sha256'], f'Prior packet changed: {name}')
    require(sha(args.source) == p.sha, 'Original source changed during verification')
    return {'result': 'PASS', 'source_sha256': p.sha, 'captures': len(expected['captures']),
            'capture_bytes_checked': checked_bytes, 'capture_byte_rows': byte_rows,
            'fixed_anchors': len(expected['anchors']), 'direct_calls': len(branches),
            'pdata_queries': len(expected['pdata']), 'imports': len(expected['imports']),
            'original_strings': len(expected['strings']), 'prior_packet_pins': len(prior_manifest['files']), 'review_status': 'Author validation only; independent review pending',
            'limits': 'Original-file static checks. No new decompilation, vendor execution, live object identity, units, or image parity.'}


if __name__ == '__main__':
    print(json.dumps(main(), indent=2))
