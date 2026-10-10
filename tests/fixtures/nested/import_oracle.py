#!/usr/bin/python3
"""Import the pinned independent oracle; add separately labelled static-policy cases.

Usage: import_oracle.py FROZEN_ORACLE_DIRECTORY OUTPUT_DIRECTORY
No application implementation supplies any expected bytes or timestamps.
"""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys

source, output = map(Path, sys.argv[1:])
oracle_path = source / 'nested-carrier-oracle.json'
oracle = json.loads(oracle_path.read_text())
output.mkdir(parents=True, exist_ok=True)
cases = []
for item in oracle['nested_fixtures']:
    raw = (source / item['path']).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == item['sha256']
    (output / item['id']).write_bytes(raw)
    case = {k: item[k] for k in ('id', 'route', 'sha256', 'outer_encoder_expected', 'outer_inventory')}
    case['claim'] = 'independent synthetic FFprobe transport; no Windows/camera parity'
    if item['id'] in ('box-META-empty.mp4', 'camd-stream-empty.mp4'):
        case['error'] = 'empty'
    elif item['id'] == 'box-camd-truncated-span.mp4':
        case['error'] = 'span'
    elif 'truncated-inner' in item['id']:
        case['error'] = 'inner-probe'
    if item.get('payload_extraction', {}).get('path'):
        extraction = item['payload_extraction']
        carrier = (source / extraction['path']).read_bytes()
        case['box'] = {k: extraction[k] for k in ('tag', 'box_offset', 'header_bytes', 'payload_offset', 'payload_length')}
    elif item.get('reconstructed_inner'):
        reconstruction = item['reconstructed_inner']
        carrier = (source / reconstruction['path']).read_bytes()
        case['parts'] = reconstruction['part_offsets']
        case['camd_indexes'] = item['camd_stream_indexes']
    else:
        carrier = None
    if carrier is not None and carrier:
        case['carrier_base64'] = base64.b64encode(carrier).decode()
        case['carrier_sha256'] = hashlib.sha256(carrier).hexdigest()
    if item.get('inner_inventory'):
        case['inner_inventory'] = item['inner_inventory']
    cases.append(case)

by_id = {c['id']: c for c in cases}
base = (source / 'nested-fixtures/box-meta-normal.mp4').read_bytes()[:1544]
oqb = base64.b64decode(by_id['camd-stream-default.mp4']['carrier_base64'])
wab = base64.b64decode(by_id['camd-stream-wab530.mp4']['carrier_base64'])
def box(tag, payload):
    return struct.pack('>I4s', 8 + len(payload), tag) + payload
for name, first_tag, first, second_tag, second, expected in [
    ('first-META-before-camd.mp4', b'META', oqb, b'camd', wab, 'camd-stream-default.mp4'),
    ('first-camd-before-META.mp4', b'camd', wab, b'META', oqb, 'camd-stream-wab530.mp4'),
    ('first-empty-META-before-camd.mp4', b'META', b'', b'camd', oqb, None),
    ('first-empty-camd-before-META.mp4', b'camd', b'', b'META', oqb, None),
]:
    raw = base + box(first_tag, first) + box(second_tag, second)
    (output / name).write_bytes(raw)
    case = dict(id=name, route='top_level_box', sha256=hashlib.sha256(raw).hexdigest(),
                outer_encoder_expected='DJI Osmo360', outer_inventory=by_id['box-meta-normal.mp4']['outer_inventory'],
                claim='native/static first-match acceptance; not vendor runtime',
                box=dict(tag=first_tag.decode(), box_offset=1544, header_bytes=8,
                         payload_offset=1552, payload_length=len(first)))
    if expected:
        case.update(carrier_base64=base64.b64encode(first).decode(),
                    carrier_sha256=hashlib.sha256(first).hexdigest(),
                    inner_inventory=by_id[expected]['inner_inventory'])
        if expected == 'camd-stream-wab530.mp4':
            case['transport_mismatch'] = True  # Shared outer encoder remains OQB.
    else:
        case['error'] = 'empty'
    cases.append(case)

manifest = dict(oracle_sha256=hashlib.sha256(oracle_path.read_bytes()).hexdigest(),
                source_generator_sha256='4523f2a58d6868677a5b42b81a4121b7f059b3244ac01dceee20682df06a617a',
                contract_sha256='f181baeefc320bb3ad4031d199ea1247c990e5f16ce6347e91187382f5701a95',
                cases=cases)
(output / 'acceptance.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Imported {len(oracle["nested_fixtures"])} frozen carriers and 4 separate first-box cases')
