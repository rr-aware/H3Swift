#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/h3-extended-tests.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM
"${CC:-clang}" -g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all \
    -DH3_EXTENDED=1 -DH3_HAVE_VLA=1 -DH3_HAVE_ALLOCA=1 \
    -Ibindings/extended/include -Ibindings/swift/include -Isrc/h3lib/include \
    bindings/extended/bridge.c bindings/extended/lib/*.c tests/extended_engine.c \
    -lm -o "$build_dir/test"
"$build_dir/test"
