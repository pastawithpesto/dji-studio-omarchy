"""Read-only, bounded PE metadata. Metadata is not recovered behavior."""
import hashlib
import mmap
import struct


def inspect_pe(path):
    with path.open('rb') as stream:
        if path.stat().st_size < 64:
            raise ValueError('Truncated PE header')
        with mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
            size = len(data)

            def read(fmt, offset):
                count = struct.calcsize(fmt)
                if offset < 0 or offset + count > size:
                    raise ValueError('PE field is outside the file')
                return struct.unpack_from(fmt, data, offset)

            if data[:2] != b'MZ':
                raise ValueError('Missing DOS signature')
            pe, = read('<I', 60)
            if data[pe:pe + 4] != b'PE\0\0':
                raise ValueError('Missing PE signature')
            machine, count = read('<HH', pe + 4)
            opt_size, = read('<H', pe + 20)
            opt = pe + 24
            magic, = read('<H', opt)
            if magic not in (0x10b, 0x20b) or count > 96:
                raise ValueError('Unsupported PE layout')
            minimum = 96 if magic == 0x10b else 112
            if opt_size < minimum or opt + opt_size + count * 40 > size:
                raise ValueError('Truncated PE tables')
            image_base, = read('<I' if magic == 0x10b else '<Q', opt + (28 if magic == 0x10b else 24))
            headers, = read('<I', opt + 60)
            directory_count, = read('<I', opt + minimum - 4)
            sections = []
            for index in range(count):
                offset = opt + opt_size + index * 40
                name = data[offset:offset + 8].split(b'\0')[0].decode('ascii', 'replace')
                virtual_size, rva, raw_size, raw_offset = read('<IIII', offset + 8)
                flags, = read('<I', offset + 36)
                if raw_size and raw_offset + raw_size > size:
                    raise ValueError('Section bytes are outside the file')
                sections.append(dict(name=name, rva=rva, va=hex(image_base + rva), virtual_size=virtual_size,
                                     raw_size=raw_size, raw_offset=raw_offset, flags=flags))

            def mapped(rva, width=1):
                if 0 <= rva < min(headers, size) and rva + width <= min(headers, size):
                    return rva
                for section in sections:
                    delta = rva - section['rva']
                    if 0 <= delta and delta + width <= section['raw_size']:
                        return section['raw_offset'] + delta
                raise ValueError('RVA has no complete original file bytes')

            def string(rva):
                offset = mapped(rva)
                end = data.find(b'\0', offset, min(size, offset + 4096))
                if end < 0:
                    raise ValueError('Unterminated PE name')
                mapped(rva, end - offset + 1)
                return data[offset:end].decode('ascii', 'replace')

            exports = []
            if directory_count and opt_size >= minimum + 8:
                export_rva, export_size = read('<II', opt + minimum)
                if export_rva and export_size:
                    table = mapped(export_rva, 40)
                    base, functions, names, eat, name_table, ordinals = read('<IIIIII', table + 16)
                    if functions > 100000 or names > 100000:
                        raise ValueError('Excessive export table')
                    eat_offset = mapped(eat, functions * 4) if functions else 0
                    named = {}
                    if names:
                        name_offset = mapped(name_table, names * 4)
                        ordinal_offset = mapped(ordinals, names * 2)
                        for index in range(names):
                            name_rva, = read('<I', name_offset + index * 4)
                            ordinal, = read('<H', ordinal_offset + index * 2)
                            if ordinal >= functions:
                                raise ValueError('Export ordinal exceeds the address table')
                            named.setdefault(ordinal, []).append(string(name_rva))
                    for index in range(functions):
                        target, = read('<I', eat_offset + index * 4)
                        if not target:
                            continue
                        forwarder = string(target) if export_rva <= target < export_rva + export_size else None
                        for name in named.get(index, [f'ordinal {base + index}']):
                            exports.append(dict(name=name, ordinal=base + index, va=hex(image_base + target),
                                                rva=target, forwarder=forwarder))
            digest = hashlib.sha256(data).hexdigest()
            return dict(sections=sections, exports=exports, sha256=digest, machine=machine, image_base=hex(image_base))
