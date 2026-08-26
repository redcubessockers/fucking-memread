#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
DBYTE_ROOT=${DBYTE_ROOT:-/home/ubuntu/dbyte-cpu-6502}
DBYTE=${DBYTE:-$DBYTE_ROOT/dbyte-v12.0.0/dbyte.exe}

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "usage: $0 <pid> <address> <size> [hex-pattern]" >&2
    exit 64
fi

make -C "$ROOT/native" all >/dev/null
tmp_dump=$(mktemp "$ROOT/live_tests/memread.XXXXXX.bin")
cleanup() {
    rm -f "$tmp_dump"
}
trap cleanup EXIT

"$ROOT/native/memread_linux_read" "$1" "$2" "$3" > "$tmp_dump"
export WINEPREFIX=${WINEPREFIX:-/home/ubuntu/dbyte-wine64-prefix}
export WINEARCH=win64
export WINEDEBUG=-all
if [ "$#" -eq 4 ]; then
    wine "$DBYTE" run "$ROOT/memread.dby" "$tmp_dump" "$4"
else
    wine "$DBYTE" run "$ROOT/memread.dby" "$tmp_dump"
fi
