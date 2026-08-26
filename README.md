# fucking-memread

A DByte-first memory inspection competitor for `siubikYT/memread`.

The project has two explicit layers. `memread.dby` is the DByte 12.0 core: it reads a user-supplied dump, applies the 32 KiB bound, emits a hexadecimal dump, searches for an optional hexadecimal byte pattern, and decodes little-endian integer values. `native/memread_linux_read.c` is a small Linux acquisition adapter that calls `process_vm_readv` for a PID/address/size supplied by the user. The adapter returns raw bytes; DByte owns parsing, search, and presentation.

This is deliberately **permission-respecting**. It does not load a kernel module, open `/dev/memreader`, call `access_process_vm`, bypass ptrace restrictions, or read an unrelated process implicitly. `process_vm_readv` is subject to the operating system's normal permission policy. A true kernel-level protected-process path would require a separately reviewed privileged driver and is not silently included here.

## Build

The DByte host package is currently distributed for Windows x64. On the sandbox, run DByte through the configured Wine prefix:

```sh
export WINEPREFIX=/home/ubuntu/dbyte-wine64-prefix
export WINEARCH=win64
export WINEDEBUG=-all
wine /home/ubuntu/dbyte-cpu-6502/dbyte-v12.0.0/dbyte.exe check memread.dby
make -C native
```

The Linux adapter is a normal x86-64 userspace ELF executable. It has no installation step and no kernel-module side effect.

## Offline mode

Inspect a dump file directly:

```sh
wine /home/ubuntu/dbyte-cpu-6502/dbyte-v12.0.0/dbyte.exe run memread.dby tests/sample.bin
```

The first runtime argument is the dump path. The output includes the full hex representation, `u8/i8/u16/i16/u32/i32` values, and for at least eight bytes the `u64` value represented as low and high 32-bit halves so the hosted i64 limit is never exceeded. Files larger than 32768 bytes are rejected.

Search for bytes by adding a hexadecimal pattern:

```sh
wine /home/ubuntu/dbyte-cpu-6502/dbyte-v12.0.0/dbyte.exe run memread.dby tests/sample.bin 4142
```

The output reports `match_offset=4` for the sample fixture. The search is performed by DByte's buffer APIs.

## Live mode

For a process that the operating system allows the caller to inspect:

```sh
./memread_live.sh <pid> <address> <size> [hex-pattern]
```

Addresses accept the C-style `0x...` form. The adapter requires a size in `1..32768`, requires a complete read, and returns a non-zero status for invalid input, permission failures, missing processes, short reads, or output failures. The temporary dump is deleted on exit. If a pattern is supplied, it is passed into the DByte search path after acquisition.

A self-contained test uses only a child fixture created by the test itself:

```sh
./live_tests/run_live_test.sh
```

## Regression tests

```sh
./run_tests.sh
./live_tests/run_live_test.sh
```

The tests check DByte syntax, deterministic offline decoding, u64 low/high extraction, hex-pattern search, the 32 KiB negative boundary, live bytes from the owned child fixture, live launcher search, invalid PID handling, and zero-size rejection. They do not require `sudo`, `insmod`, or a kernel module.

## Comparison boundary

The original [`siubikYT/memread`](https://github.com/siubikYT/memread) combines a C++ ImTUI client with a Linux kernel driver that registers `/dev/memreader` and calls `access_process_vm`. This project competes on DByte ownership, a small auditable adapter, explicit permission behavior, typed/searchable dump handling, and reproducible tests. It is not honest to claim complete protected-process feature parity until a privileged kernel boundary is separately implemented and verified.

## License

This repository retains its existing GPL-2.0 license. New project code is intended to remain compatible with that repository license.

## References

- [siubikYT/memread](https://github.com/siubikYT/memread)
- [DByte 12.0 documentation](https://dbytelang.site/docs/12.0/)
- [DByte hosted stdlib](https://dbytelang.site/docs/12.0/reference/stdlib/)
