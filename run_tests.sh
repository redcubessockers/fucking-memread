#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
DBYTE_ROOT=${DBYTE_ROOT:-/home/ubuntu/dbyte-cpu-6502}
DBYTE=${DBYTE:-$DBYTE_ROOT/dbyte-v12.0.0/dbyte.exe}
WINEPREFIX=${WINEPREFIX:-/home/ubuntu/dbyte-wine64-prefix}
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG=-all
mkdir -p "$ROOT/evidence" "$ROOT/tests"
printf '\x01\x02\x03\x04\x41\x42\x43\x44' > "$ROOT/tests/sample.bin"
wine "$DBYTE" check "$ROOT/memread.dby"
output=$(wine "$DBYTE" run "$ROOT/memread.dby" "$ROOT/tests/sample.bin")
printf '%s\n' "$output" > "$ROOT/evidence/offline_sample.log"
printf '%s\n' "$output" | grep -F 'DBYTE_MEMREAD_OFFLINE'
printf '%s\n' "$output" | grep -F 'size_bytes'
printf '%s\n' "$output" | grep -x '8'
printf '%s\n' "$output" | grep -F '0102030441424344'
printf '%s\n' "$output" | grep -x '513'
printf '%s\n' "$output" | grep -x '67305985'
printf '%s\n' "$output" | grep -F 'u64_le@0_low_u32'
printf '%s\n' "$output" | grep -F 'u64_le@0_high_u32'
search_output=$(wine "$DBYTE" run "$ROOT/memread.dby" "$ROOT/tests/sample.bin" 4142)
printf '%s\n' "$search_output" > "$ROOT/evidence/hex_search.log"
printf '%s\n' "$search_output" | grep -F 'hex_pattern'
printf '%s\n' "$search_output" | grep -x '4'
dd if=/dev/zero of="$ROOT/tests/too_large.bin" bs=32769 count=1 status=none
large_output=$(wine "$DBYTE" run "$ROOT/memread.dby" "$ROOT/tests/too_large.bin")
printf '%s\n' "$large_output" > "$ROOT/evidence/size_limit.log"
printf '%s\n' "$large_output" | grep -F 'DBYTE_MEMREAD_ERROR_SIZE_LIMIT'
printf '%s\n' "$large_output" | grep -x '32769'
printf 'MEMREAD_DBYTE_TEST_PASS\n'
