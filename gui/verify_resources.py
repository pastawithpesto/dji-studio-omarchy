#!/usr/bin/env python3
"""Verify frozen resource bytes/provenance, then generate our resource table."""
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
MANIFEST_SHA = '443a67dc71ef6a07df4619a52507b1491267eaab3b999ba5f6b19dca5e2f1b98'

def require(condition, message):
    if not condition:
        raise SystemExit(message)

raw = (ROOT / 'resource-manifest.json').read_bytes()
require(hashlib.sha256(raw).hexdigest() == MANIFEST_SHA, 'Frozen manifest identity changed')
manifest = json.loads(raw)
require(manifest['contract_sha256'] == '13dc8440f94d9ca453d53109876f920634e24a99a44cc36a8c763b41e00feda0', 'Wrong contract')
require(manifest['reference_exe_sha256'] == 'e8732b263ea6486680a3007349b9c06a37cfb64c8797610743fd3b3831b0faf4', 'Wrong original reference')
require(len(manifest['records']) == 1463, 'Wrong resource count')
aliases = set()
document = ET.Element('RCC')
resource = ET.SubElement(document, 'qresource', prefix='/')
for row in manifest['records']:
    alias = row['alias']
    path = (ROOT / row['file']).resolve()
    require(path.is_relative_to(ROOT / 'resources') and alias.startswith('/') and
            '..' not in Path(alias).parts and alias not in aliases, 'Invalid or duplicate resource path')
    aliases.add(alias)
    data = path.read_bytes()
    require(len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'], row['file'])
    ET.SubElement(resource, 'file', alias=alias[1:]).text = row['file']
require(sum(not alias.startswith('/native/') for alias in aliases) == 1458, 'Wrong original alias count')
for alias, path in [('native/resource-manifest.json', 'resource-manifest.json'),
                    ('native/NativeStitchedFlow.qml', 'NativeStitchedFlow.qml')]:
    ET.SubElement(resource, 'file', alias=alias).text = path
text = ET.tostring(document, encoding='unicode') + '\n'
if '--check' in sys.argv:
    require((ROOT / 'resources.qrc').read_text() == text, 'Resource registration differs')
else:
    (ROOT / 'resources.qrc').write_text(text)
print('Verified 1458 original aliases and 5 complete subset files')
