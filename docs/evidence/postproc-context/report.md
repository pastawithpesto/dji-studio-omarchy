# `postproc-58.dll`: context and identity export evidence

This packet covers the two public context exports, `pp_get_context` and `pp_free_context`, and the four identity exports `postproc_version`, `postproc_configuration`, `postproc_license`, and `postproc_ffversion`. The target is the DJI Studio 1.0.0.30839 PE32+ x86-64 DLL, 99,512 bytes, SHA-256 `fcb300de9e4702545991c4487e0ee90728090f22f3639c4bf6adc0bd4a03617b`.

The DLL was not executed. Ghidra/REA analysis and source-byte reads stayed in a private REA 6.4.0 installation using Ghidra 12.1.4. Two nonblocking acquisitions of the shared import lock covered the export-stub and implementation-target captures; both sessions closed normally. The target SHA-256 matched before and after each session. `tool-pins.json` records the upstream REA commit, MCP/SDK versions, catalog digests, paths, heap, Java, LLVM, and lock configuration.

## Export mapping

LLVM `llvm-readobj` and an independent PE parser agree on the ten exact export names, ordinals, and RVAs. The parser independently maps each RVA to its file offset. Ghidra’s imported-name inventory contains every name once at the matching VA; that name inventory does not report ordinals. This comparison establishes the complete export table only; analysis below is limited to the six named exports.

| Exact export name | Ordinal | Export RVA / file offset | Captured target or data |
| --- | ---: | --- | --- |
| `postproc_configuration` | 1 | `0x102d` / `0x42d` | JMP to `0x18000b910`; returns the string at `0x180012ba0` |
| `postproc_ffversion` | 2 | `0x12b78` / `0x11778` | Exported data; `FFmpeg version 7.0.2` |
| `postproc_license` | 3 | `0x119a` / `0x59a` | JMP to `0x18000b920`; returns the string at `0x18001341d` |
| `postproc_version` | 4 | `0x1019` / `0x419` | JMP to `0x18000b930`; returns `0x3a0164` |
| `pp_free_context` | 5 | `0x1082` / `0x482` | JMP to `0x180009340`; 199-byte implementation body |
| `pp_get_context` | 7 | `0x1087` / `0x487` | JMP to `0x180009450`; 233-byte implementation body |

The selected code exports are five-byte `E9 rel32` thunks. Their destinations were decoded from the original bytes and matched Ghidra’s thunk targets. The implementation bodies were queried separately because the export-stub bodies contain only those jumps. The table, source ranges, body hashes, full byte witnesses, Ghidra pseudocode and assembly, and REA evidence IDs are in [`source-map.json`](source-map.json).

## Context construction

At `0x180009450`, the implementation reached through `pp_get_context` calls `AVUTIL-59.DLL::av_mallocz` with `0x560` bytes. It tests the returned pointer and returns null on the zero result. On the non-null path, the captured instructions write a pointer-sized value at context offset `0x00`; write the two parameter-3-derived dwords at offsets `0x520` and `0x524`; write the CPU-related dword at `0x514`; call the internal initializer at `0x18000a970`; then write `0xffffffff` at `0x510` before returning the context pointer.

The observed parameter-3 policy is:

| Condition | Dword at `+0x520` | Dword at `+0x524` | Dword at `+0x514` |
| --- | --- | --- | --- |
| bit 3 clear | `1` | `1` | `1` if bit 28 is set, else `0` |
| bit 3 set | `param3 & 3` | `(param3 >> 4) & 3` | `1` if bit 28 is set, else `0` |
| bit 19 set | same mode fields as above | same mode fields as above | result of `AVUTIL-59.DLL::av_get_cpu_flags()`; this branch takes precedence over the bit-28 fallback |

The initializer call receives the context, the original first and second integer parameters, the first parameter rounded up to a 16-unit boundary, and a signed 32-bit adjusted value. The machine sequence computes `u = uint32(param1 + 15)`, `aligned = u & 0xfffffff0`, and `adjusted = (int32(u + (signbit(u) ? 15 : 0)) >> 4) + 2`, with 32-bit wraparound before the arithmetic shift. For nonnegative sample widths `0, 1, 15, 16, 17, 31, 32, 33`, the offline oracle records aligned values `0, 16, 16, 16, 32, 32, 32, 48` and adjusted values `2, 3, 3, 3, 4, 4, 4, 5`. The second integer parameter is forwarded unchanged. The initializer’s body is not analyzed here, so this packet makes no claims about its internal allocations or the rest of the context state.

Ghidra’s recovered C-like pseudocode is included in the source map alongside its separate assembly view. LLVM 22.1.8 independently disassembled the source bytes. The following excerpt records the key register-level evidence using numeric addresses:

```asm
18000946e: b9 60 05 00 00                 movl    $0x560, %ecx
180009476: e8 c1 24 00 00                 callq   0x18000b93c
180009494: 48 85 db                       testq   %rbx, %rbx
180009497: 75 07                          jne     0x1800094a0
180009499: 33 c0                          xorl    %eax, %eax
18000949b: e9 80 00 00 00                 jmp     0x180009520
1800094af: 40 f6 c7 08                    testb   $0x8, %dil
1800094c8: 89 83 24 05 00 00              movl    %eax, 0x524(%rbx)
1800094ce: 89 8b 20 05 00 00              movl    %ecx, 0x520(%rbx)
1800094d4: 0f ba e7 13                    btl     $0x13, %edi
1800094da: e8 75 24 00 00                 callq   0x18000b954
1800094e1: c7 83 14 05 00 00 00 00 00 00 movl    $0x0, 0x514(%rbx)
1800094eb: 0f ba e7 1c                    btl     $0x1c, %edi
1800094f8: 44 8b ce                       movl    %esi, %r9d
1800094fb: 89 83 14 05 00 00              movl    %eax, 0x514(%rbx)
18000950e: e8 5d 14 00 00                 callq   0x18000a970
180009516: c7 83 10 05 00 00 ff ff ff ff movl    $0xffffffff, 0x510(%rbx)
```

For `pp_free_context`, LLVM confirms the `+0x28` and `+0x40` loops each load pointer slots with an 8-byte stride and stop at count three, the eight separately addressed slots, the `memset` call with zero and `0x560`, and a final jump to the AVUTIL free thunk. The offline validator checks those instruction encodings and call targets without loading or executing the DLL.

## Context free policy

The implementation reached through `pp_free_context` is 199 bytes. It passes 14 pointer values to the imported `AVUTIL-59.DLL::av_free`: three consecutive 8-byte slots beginning at `context+0x28`, three beginning at `context+0x40`, then slots at `+0x08`, `+0x10`, `+0x58`, `+0x60`, `+0x68`, `+0x4c0`, `+0x4c8`, and `+0x4d0`. It then calls `VCRUNTIME140.DLL::memset(context, 0, 0x560)` and tail-jumps to `AVUTIL-59.DLL::av_free(context)`.

The first context-relative load follows setup of the `+0x28` pointer walk; no null-context guard precedes that access in the captured body. This describes the observed static path. It does not establish caller obligations, `av_free` null behavior, alias safety between stored pointers, or whether the cleanup order is safe for every possible state.

## Identity and version exports

| Export | Static result | Source evidence |
| --- | --- | --- |
| `postproc_version` | `MOV EAX, 0x3a0164; RET`, so the function returns `0x3a0164` (3,801,444) | implementation VA `0x18000b930`, six bytes, SHA-256 `a24275eee4cd257339c49babb183f7de76c9ce778e177b6e89b9e0275e791a77` |
| `postproc_configuration` | Returns a pointer to a 1,791-byte NUL-terminated build-configuration string | implementation VA `0x18000b910`; decoded RIP-relative target `0x180012ba0`; string SHA-256 excluding NUL `6793c5e6ddca7a58d043a832eef348bc0d98f7650af40ac3990db65099557e8c` |
| `postproc_license` | Returns the exact string `nonfree and unredistributable` | implementation VA `0x18000b920`; decoded RIP-relative target `0x18001341d`; 29 bytes excluding NUL |
| `postproc_ffversion` | Exported data contains the exact string `FFmpeg version 7.0.2` | data RVA `0x12b78`, file offset `0x11778`; 20 bytes excluding NUL; provider bytes equal source bytes |

The complete `postproc_configuration` string, including the recorded build paths and options, is preserved in the source map. Each pointer and NUL-terminated string was checked against the original PE bytes; `postproc_ffversion` was also read through REA/Ghidra and matched to the independent file offset and source bytes.

## Validation and limits

Run `python3 validate_packet.py /path/to/postproc-58.dll source-map.json` from this directory to parse the PE independently and check its export names, ordinals and RVAs; verify all five export thunks and five implementation-body bytes against the source map; decode the version immediate and RIP-relative string pointers; verify the exact strings; check the captured context and free instruction patterns; and evaluate finite width/flag vectors. The recorded output is [`validation.json`](validation.json). [`manifest.json`](manifest.json) records SHA-256 and sizes for the report, source map, pins, validator, validation output, and task record.

Ghidra’s C signatures and generated names such as `FUN_180009450` are analysis labels, not established source declarations or original names. The `av_mallocz`, `av_free`, `av_get_cpu_flags`, and `memset` implementations are outside this packet. The call at `0x18000a970` is an explicit unresolved boundary. The other four exports, `pp_free_mode`, `pp_get_mode_by_name_and_quality`, `pp_help`, and `pp_postprocess`, were inventoried but not analyzed. This packet does not establish full-DLL coverage, runtime behavior, processing output, pixel/filter equivalence, or DJI Studio parity.
