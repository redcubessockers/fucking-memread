#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DBYTE_ROOT=${DBYTE_ROOT:-/home/ubuntu/dbyte-cpu-6502}
DBYTE=${DBYTE:-$DBYTE_ROOT/dbyte-v12.0.0/dbyte.exe}
WINEPREFIX=${WINEPREFIX:-/home/ubuntu/dbyte-wine64-prefix}
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG=-all
mkdir -p "$ROOT/evidence" "$ROOT/tests" "$ROOT/live_tests"

make -C "$ROOT/native" all >/dev/null
cc -O2 -std=c11 -Wall -Wextra -Werror -D_FORTIFY_SOURCE=2 "$ROOT/live_tests/fixture.c" -o "$ROOT/live_tests/fixture"

"$ROOT/live_tests/fixture" > "$ROOT/live_tests/fixture.info" &
fixture_launcher_pid=$!
cleanup() {
    kill "$fixture_launcher_pid" 2>/dev/null || true
    wait "$fixture_launcher_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 100); do
    if [ -s "$ROOT/live_tests/fixture.info" ]; then
        break
    fi
    sleep 0.01
done
if [ ! -s "$ROOT/live_tests/fixture.info" ]; then
    echo "fixture did not publish address" >&2
    exit 1
fi
read -r fixture_pid fixture_address fixture_size < "$ROOT/live_tests/fixture.info"
"$ROOT/native/memread_linux_read" "$fixture_pid" "$fixture_address" "$fixture_size" > "$ROOT/live_tests/live_dump.bin"
printf '\x01\x02\x03\x04\x41\x42\x43\x44' > "$ROOT/tests/sample.bin"
cmp "$ROOT/live_tests/live_dump.bin" "$ROOT/tests/sample.bin"

wine "$DBYTE" check "$ROOT/memread.dby" >/dev/null
wine "$DBYTE" run "$ROOT/memread.dby" "$ROOT/live_tests/live_dump.bin" > "$ROOT/evidence/live_dbyte_output.log"
grep -F '0102030441424344' "$ROOT/evidence/live_dbyte_output.log" >/dev/null
grep -x '513' "$ROOT/evidence/live_dbyte_output.log" >/dev/null
grep -x '67305985' "$ROOT/evidence/live_dbyte_output.log" >/dev/null
live_search_output=$("$ROOT/memread_live.sh" "$fixture_pid" "$fixture_address" "$fixture_size" 4142)
printf '%s\n' "$live_search_output" > "$ROOT/evidence/live_launcher_search.log"
printf '%s\n' "$live_search_output" | grep -F 'hex_pattern' >/dev/null
printf '%s\n' "$live_search_output" | grep -x '4' >/dev/null

if "$ROOT/native/memread_linux_read" 0 "$fixture_address" 1 >/dev/null 2>&1; then
    echo "invalid pid unexpectedly succeeded" >&2
    exit 1
fi
if "$ROOT/native/memread_linux_read" "$fixture_pid" "$fixture_address" 0 >/dev/null 2>&1; then
    echo "zero size unexpectedly succeeded" >&2
    exit 1
fi
printf 'MEMREAD_DBYTE_LIVE_TEST_PASS pid=%s address=%s bytes=%s\n' "$fixture_pid" "$fixture_address" "$fixture_size"
