# Resource SDK scalar oracles

ORACLES.json was prepared before the Rust implementation. Its 12 hash vectors
use arbitrary-precision XOR/multiplication modulo2^64. Its 25 bucket vectors
use repeated integer doubling, with explicit0/1 edges and the unsigned2^59 guard.
The independent contract reviewer verified all37 records against the original
scalar equations and bytes. No vendor program or Rust function generated them.

Original source: DJI Studio1.0.0.30839 resource_sdk.dll SHA-256
006190faece698a6fffc6da68eacff3a996f75b1d6e362515cf2fa21bd58587d.
REA6.4.0 contract SHA-256:
815f466606b6f5f35729ec9796254071d83160238015457b2e7c78955f7df943.
ORACLES.json SHA-256:
4724c0d609fd9a99b124528e674a40e0ad1457891a259f2e7dfdb7266d322950.

These fixtures validate static scalar translation only. They do not test the
original allocator, container mutation, MSVC string ABI, filesystem behavior,
Windows runtime or full SDK compatibility. Native typed errors are independent
API policy and do not reproduce C++ exceptions or allocation failures.
