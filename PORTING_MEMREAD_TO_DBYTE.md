# Porting memread to DByte 12.0

## Scope

This repository now contains a DByte-first memory inspection vertical slice. The DByte program owns dump loading, size checks, hexadecimal output, and typed decoding. A small Linux userspace adapter owns live acquisition through `process_vm_readv`; it returns raw bytes to the DByte layer.

This split is intentional. The original [`siubikYT/memread`](https://github.com/siubikYT/memread) is a C++ ImTUI client plus a Linux kernel driver. The client opens `/dev/memreader` and issues `_IOWR('M', 1, struct mem_read_request)`. The driver resolves a task, calls `access_process_vm`, copies bytes to userspace, and is intended for targets that ordinary debuggers cannot attach to. A hosted DByte program cannot reproduce a privileged ioctl/kernel-module boundary using only the documented hosted standard library.[1] [2]

## DByte layer

`memread.dby` uses `std.env`, `std.fs.read_bytes`, `std.encoding.hex_encode`, and `std.binary`. It accepts one dump path, rejects data larger than 32768 bytes, prints the bytes as hex, and decodes little-endian `u8`, `i8`, `u16`, `i16`, `u32`, and `i32` values. It never opens a process handle and never attempts to bypass ptrace or operating-system permissions.

The 32768-byte bound mirrors the maximum request size in the reference driver. The hosted API loads the file before the length check, so a future production API should provide bounded or streaming reads if input may be untrusted or very large.

## Linux acquisition layer

`native/memread_linux_read.c` is a deliberately small, auditable adapter. It accepts exactly `<pid> <address> <size>`, parses numeric values with base autodetection, restricts size to `1..32768`, calls `process_vm_readv` once, requires a complete read, and writes raw bytes to stdout. It returns failure for malformed arguments, allocation failure, permission denial, missing processes, short reads, interrupted/output failures, or an invalid size.

The adapter does not use `sudo`, `insmod`, `/dev/memreader`, `access_process_vm`, kernel symbols, or a hidden C++ parser. It therefore supports processes that the operating system already allows the caller to inspect, not the protected-process bypass promised by the reference kernel module.

## Build and run

```sh
make -C native

export WINEPREFIX=/home/ubuntu/dbyte-wine64-prefix
export WINEARCH=win64
export WINEDEBUG=-all
wine /home/ubuntu/dbyte-cpu-6502/dbyte-v12.0.0/dbyte.exe check memread.dby
wine /home/ubuntu/dbyte-cpu-6502/dbyte-v12.0.0/dbyte.exe run memread.dby tests/sample.bin
```

For live mode:

```sh
./memread_live.sh <pid> <address> <size>
```

The launcher creates a temporary dump, invokes the native adapter, sends that dump into `memread.dby`, and removes the temporary file on exit.

## Verification

`run_tests.sh` checks DByte syntax, a deterministic eight-byte dump, expected hex encoding, little-endian values, and the oversized-file rejection. `live_tests/run_live_test.sh` builds a child fixture owned by the test, reads exactly eight bytes from that child with `process_vm_readv`, compares the raw bytes, runs the DByte decoder, and checks invalid PID and zero-size failures. No external process is used by the tests.

Expected positive values for bytes `01 02 03 04 41 42 43 44` are `u16_le=513` and `u32_le=67305985`.

## Security and ownership boundary

The caller owns the decision to provide a PID, address, and size. The native adapter validates syntax and size, while the kernel validates process permissions and address accessibility. The DByte layer owns only the returned byte buffer and formatting. The temporary dump is deleted by the launcher, and no memory is written to the target process.

## License

The repository retains its existing GPL-2.0 license. New files are intended to remain compatible with that license.

## References

[1]: https://github.com/siubikYT/memread "siubikYT/memread reference implementation"

[2]: https://dbytelang.site/docs/12.0/reference/stdlib/ "DByte 12.0 hosted standard library"

## Feature expansion

The DByte layer now exposes an optional hexadecimal-pattern search. It decodes the pattern with `std.encoding.hex_decode`, converts the input to a DByte buffer, and uses `std.buffer.find` to report the first byte offset. The live launcher accepts the same optional pattern after `<pid> <address> <size>` and passes it to the DByte program after acquisition.

The reference client supports 64-bit integer display. Hosted DByte's documented binary surface provides 32-bit reads, so the DByte program reports a 64-bit little-endian value as `u64_le@0_low_u32` and `u64_le@0_high_u32`. This preserves all 64 bits without constructing an out-of-range hosted i64 literal. The probe for bytes `88 77 66 55 44 33 22 11` produced low half `1432778632` and high half `287454020`.

The live integration test now checks the entire path: an owned child fixture exposes eight bytes, the native adapter reads them, the DByte decoder verifies the hex and typed values, the launcher performs a DByte-owned pattern search, and invalid PID/zero-size cases fail. No unrelated process, kernel module, or permission bypass is used.
