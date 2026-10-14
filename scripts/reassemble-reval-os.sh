#!/bin/sh
set -eu
name=reval-os-0.2-universal-x86_64.iso
cat "$name".part-*.bin > "$name"
sha256sum -c SHA256SUMS
echo "ISO восстановлен: $name"
