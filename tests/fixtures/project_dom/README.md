# Restricted ordered DOM serialization fixtures

These are static/analytic successful byte rules and independent native policy
cases. They are not executed-DLL or Windows project save/reopen fixtures.

Source: DJI Studio1.0.0.30839 nle_core.dll SHA256
3b5d3931c5a0b0796ea5a0072a0102bc6f38d24c94ad56cb62abe31e3d7e99b1.
Successful compact bytes are supported by original150b70/153190, string/decimal
tables and the restricted integral-real path14e370; reflected CRC32 at131500
hashes the serialized data length, excluding its NUL, not an entire envelope.

Astra522 approves BYTE-CONTRACT-R1 SHA256
49886bbb5a453e3aaf288c0d2a39790bc779792721ad0e31adc60f24d980a37b.
Astra565 approves IMPLEMENTATION-CONTRACT-R1 SHA256
c8d9e215db9d402b0617953f5f49e7625ee7f27be7d47357a36231acf67f657b,
manifest378e658e1dab7d7ff190162f22b42f463bdb588a94e470c1a4dc8e4e047f0313.
Reports reside in sol-review/swarm-20261010-2154/project-dom-contract and
project-dom-implementation-contract in the preserved reconstruction workspace.

The five JSON files are exact copies of the approved11-artifact contract:

- approved-byte-fixtures.json:23 handliteral successes and10 exclusions;
  SHA2560c2abe8c2c0da0aca286b506a77b67fb9bfd22ed90f24d498150780ccbd60460.
- bounds-fixtures.json:46 independent native count/cap/error-order cases,
  with repeat specifications for large inputs and literal output patterns.
- fault-fixtures.json:five private reserve-denial/append-invariant cases.
- exclusions-api-map.json:five runtime real errors and five inputs excluded
  by safe typed construction. The test fixture adapter rejects extra fields,
  invalid UTF8, raw kinds and writer options; it is not a project parser.
- raw-crc-fixtures.json:six481/482-approved raw-span cases, including embedded
  NUL, invalid UTF8 and all256 byte values.

The defaults/hard maxima32MiB output, depth64 and100000 value/key records,
preorder/error precedence, atomic output-cost chunks, fallible allocation and
explicit rejection are native design. Signed zero and integral finite real
magnitudes1..2^53-1 are the only successful F64Bits domain. Input/unknown schema,
numeric precision metadata, parser numeric/order/duplicate/Unicode behavior,
general real rounding and project envelope/save/recovery remain unsupported.
The raw signature helper deliberately hashes the complete borrowed span with no
JSON validation or serializer caps. Output bytes and CRC are separate fields.

Root570 assigns source worktree on09f1eee5c1f6e37dbe618b5c123008081b00e166.
Separate exact committed source review and root integration are required;
native tests and static evidence do not establish Windows compatibility.
