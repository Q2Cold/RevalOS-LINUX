#!/bin/sh
set -eu
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p "$repo_dir/build"
"${CC:-cc}" -O2 -Wall -Wextra \
    "$repo_dir/reval/src/layout/myos-layout.c" \
    -o "$repo_dir/build/reval-layout" \
    -lX11
printf 'Собрано: %s/build/reval-layout\n' "$repo_dir"
