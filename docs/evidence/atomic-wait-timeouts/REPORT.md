# Bounded atomic-wait timeout behavior

This packet recovers two exports from the DJI Studio 1.0.0.30839 copy of `msvcp140_atomic_wait.dll`. The source is 57,376 bytes with SHA-256 `ae430f3b65c5fc88643b30a344289bfda29811279379c1537cec19983c0938ae`. The original file and the complete raw capture remain local; this packet contains only the relevant code and byte ranges.

## Recovered behavior

`__std_atomic_wait_get_deadline` (ordinal 11, RVA `0x15c0`, VA `0x1800015c0`) accepts a 64-bit value in `RCX` and returns the computed 64-bit value in `RAX`. If the input is all ones (`UINT64_MAX`), it returns that value without reading the clock. Otherwise, it calls the imported `KERNEL32.dll!GetTickCount64` at call site `0x1800015d2` and performs a 64-bit addition. The add has no carry check or saturation. The machine result therefore wraps modulo 2^64. A finite input and a time value can add to `UINT64_MAX`, colliding with the sentinel.

`__std_atomic_wait_get_remaining_timeout` (ordinal 12, RVA `0x15f0`, VA `0x1800015f0`) accepts a 64-bit deadline in `RCX`. An all-ones deadline returns `0xffffffff` without reading the clock. Otherwise it calls the same import at `0x180001604`. An unsigned comparison returns zero when the current value is equal to or above the deadline. For a future deadline, it subtracts the current value from the deadline and returns the lesser of that difference and `0x337f9800` (`864000000`). The comparison uses a strict `JA` for values above the cap; equality also returns the cap value.

Every return path in the remaining-timeout body writes `EAX`. On x86-64, writing `EAX` zero-extends into `RAX`; in particular the sentinel path returns `0x00000000ffffffff`, rather than the 64-bit all-ones value. Ghidra inferred `ulonglong` for its signature, but that decompiler type is not proof of the source declaration. The PE export provides no formal C/C++ prototype. The deadline function uses a qword add and RAX result, but its formal signedness is also not established by these bytes.

The target bytes prove that both non-sentinel paths read the imported time source. The separate Microsoft API contract documents `GetTickCount64` as returning milliseconds since system start, with typical resolution of 10–16 ms. On that documented unit, `864000000` is 10 days. Microsoft also documents that this elapsed count includes sleep or hibernation. These API facts describe the named import; they do not expand the recovered DLL scope. See [GetTickCount64 function](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-gettickcount64) and [Windows Time](https://learn.microsoft.com/en-us/windows/win32/sysinfo/windows-time).

## Source evidence

LLVM and GNU PE inventories independently identify the requested exports at ordinals 11 and 12 and RVAs `0x15c0` and `0x15f0`. The PE import tables identify `KERNEL32.dll!GetTickCount64` at IAT RVA `0x50d0`; the target's two indirect calls reference VA `0x1800050d0`. Ghidra's function bodies cover 33 bytes at file offset `0x9c0` and 56 bytes at file offset `0x9f0`. Their SHA-256 values are `91a621460251e107081a5c4abe58a32f74745cd2b6d93cc8fca49a9dca158b88` and `2090187ba92fcec6d04afdfdf1e278feaeb834ad6bef76ad6b7f1c62370516ad`, respectively. Both ranges were independently rehashed from the pinned original file.

The saved Ghidra pseudocode and assembly accompany this report. Their evidence IDs and exact source bytes are listed in [`source-map.json`](source-map.json). LLVM's byte-bearing disassembly agrees with the instructions used for the arithmetic, comparisons, return width, and call target. The toolchain record pins official REA main at `fa87dd2aac3eaeb49875c54e93ec18c98cc92e4d`, package and running server 6.4.0, Ghidra 12.1.4, Node 26.9.0, Java 21.0.12.1, and a configured Ghidra headless heap limit of 768M. This was one baseline static analysis; no optimization adoption is claimed.

## Independent model and limits

[`reference_model.py`](reference_model.py) applies the recovered arithmetic to explicit synthetic 64-bit time inputs. Its 11 cases cover the two sentinel values, expired/equal deadlines, the cap boundaries, a finite addition that wraps to the sentinel, and a finite addition that wraps to zero. It never loads or executes the vendor DLL. Its passing output is in [`reference-model-results.txt`](reference-model-results.txt).

This is a bounded static contract for the two named exports. It does not recover the formal C++ declarations, cover the rest of the DLL, establish wait-loop or thread-wakeup behavior, or claim equivalence with Windows execution. The observed time source and arithmetic are pinned to this exact DLL build; the Microsoft citations document only the imported API contract.
