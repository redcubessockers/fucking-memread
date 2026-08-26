# DByte memread vs siubikYT/memread

## Honest verdict

This repository now contains a DByte-first competitor with an end-to-end live-read path for processes that the operating system permits the caller to inspect. It is still **not feature-equivalent** to `siubikYT/memread`: the reference project includes a Linux kernel driver intended to access ptrace-protected targets, while this project deliberately uses the permission-respecting `process_vm_readv` userspace API. A claim that DByte has already beaten the reference would be false.

The current advantage is architectural transparency: DByte owns the dump parser and presentation, the native boundary is small and auditable, tests use an owned child fixture, and no kernel module or hidden C++ semantics are required.

## Snapshot

| Side | Revision | Verified contents |
|---|---|---|
| DByte competitor | local commits `281cf50` and `64a1712` plus the current uncommitted live adapter work | DByte decoder, Linux adapter, launcher, tests, English documentation |
| Reference | `siubikYT/memread` commit `52419ee` | C++ ImTUI client, C Linux driver, Makefiles, bundled ImTUI/ImGui headers/libs |
| Target repository baseline | `redcubessockers/fucking-memread` upstream `d461599` | Initially contained only `LICENSE` and `YANKEE.TXT` |

The two earlier local commits were prepared for push, but GitHub HTTPS authentication was unavailable in the sandbox. The new live adapter and English documentation must be committed before a later push.

## Feature comparison

| Capability | DByte competitor | siubikYT/memread | Result |
|---|---|---|---|
| Primary implementation language | DByte 12.0 decoder and output layer | C++23 client plus C kernel module | DByte wins the language goal |
| Offline dump inspection | Yes, via `std.fs.read_bytes` | Not the main client path | DByte |
| Hex output | Yes, via `std.encoding.hex_encode` | Yes, through the UI scan view | Comparable concept, different UI |
| Typed decoding | `u8/i8/u16/i16/u32/i32` little-endian | 8/16/32/64-bit integers, char, float, double | Reference supports more types |
| Live process acquisition | Yes, for OS-permitted processes through `process_vm_readv` | Yes, through `/dev/memreader` and kernel `access_process_vm` | Reference has the stronger privilege boundary |
| Protected-process bypass | No | Intended by the reference README | Reference |
| Kernel installation | None | Requires kernel module build and `insmod` | DByte is simpler/safer |
| Temporary dump lifecycle | Launcher deletes the temporary file | Client owns an in-memory vector | Different ownership models |
| Negative tests | Invalid PID, zero size, short/complete-read contract, 32 KiB bound | Driver source validates command, pointer copy and 32 KiB bound | DByte has a reproducible local test; reference has a stronger kernel path |
| Build portability | DByte host package plus ordinary Linux adapter | C++23, ImTUI/ImGui, ncurses, matching kernel headers | DByte has fewer privileged dependencies |

## API boundary

The reference client sends a 40-byte request containing `u32 pid`, `u32 reserved`, `u64 address`, `u64 size`, and `u64 buffer` through `_IOWR('M', 1, struct mem_read_request)`. The reference driver validates the command, resolves a task, rejects zero or over-32768-byte requests, calls `access_process_vm`, copies bytes to the user pointer, and returns an error code.

The DByte competitor accepts the same conceptual PID/address/size inputs at the launcher boundary but uses a userspace adapter. The adapter validates numeric syntax, requires size `1..32768`, invokes `process_vm_readv` once, rejects short reads, writes exactly the returned bytes, and terminates with an error for invalid input or kernel-denied access. DByte then reads that byte file and owns all decoding/output.

## Fresh test evidence

The offline suite passed with the fixture `01 02 03 04 41 42 43 44`, producing hex `0102030441424344`, `u16_le=513`, and `u32_le=67305985`. The oversized 32769-byte input was rejected.

The live suite created its own child fixture, read exactly eight bytes from the published address, compared the raw output byte-for-byte, ran the DByte decoder, and checked invalid PID and zero-size failures. The result was `MEMREAD_DBYTE_LIVE_TEST_PASS`.

No external target process was used, no `sudo` or `insmod` was used, and no memory was written to another process.

## Build observations for the reference

The reference client Makefile in the checked-out tree initially failed because it includes `imtui/imtui-impl-ncurses.h` while the repository stores the header at the root of its include directory. A temporary include overlay allowed compilation to continue, but linking failed in the sandbox because `libncurses` was unavailable. The driver Makefile required `/lib/modules/6.1.102/build`, which was not present. These are observations about this sandbox and checkout, not proof that the reference cannot build on a correctly provisioned Linux machine.

## Performance comparison

There is no valid apples-to-apples runtime winner yet. The DByte offline path and the reference live kernel/UI path have different work, privilege, I/O and display costs. A fair benchmark must either compare decoder-only processing of identical dumps or compare live acquisition on the same Linux machine with identical PID/address/size requests and output sinks. Until that protocol exists, performance claims are not meaningful.

## Next step for true parity

True protected-process parity requires a separately reviewed privileged Linux boundary, likely a kernel module or another explicitly authorized mechanism, with pointer/length/permission validation, ABI tests, fault injection and cleanup tests. That boundary should remain separate from the DByte parser. The current adapter is the safer minimal feature slice and must not be advertised as a ptrace bypass.

## References

[1]: https://github.com/siubikYT/memread "siubikYT/memread reference repository"

[2]: https://dbytelang.site/docs/12.0/ "DByte 12.0 documentation"

[3]: https://dbytelang.site/docs/12.0/reference/stdlib/ "DByte 12.0 hosted standard library"

## New feature-equivalence work

The competitor now has a live acquisition adapter for OS-permitted processes. It accepts `<pid> <address> <size> [hex-pattern]`, enforces the 1..32768-byte range, requires a complete `process_vm_readv` result, writes a temporary dump, and sends that dump into the DByte parser. The DByte layer performs the optional hexadecimal-pattern search and reports the first offset.

The DByte typed view now includes low/high 32-bit halves for an eight-byte little-endian value. This represents the full 64-bit payload without exceeding the hosted i64 literal range. It also has deterministic offline pattern search through `std.buffer.find`.

The new live test is an E5-style integration check over an owned child fixture: it verifies the acquisition boundary, raw byte equality, DByte output, launcher search, invalid PID failure, and zero-size failure. It does not demonstrate access to a protected process, because the operating system is intentionally the authority for permission checks.

## Updated verdict

The project is now a stronger, runnable competitor than the original empty target repository and it satisfies the DByte-first implementation goal. It still does not beat `siubikYT/memread` on protected-process capability because the reference's kernel driver can call `access_process_vm`, while this project intentionally does not bypass ptrace or process permissions. Feature parity is therefore partial, not complete.
