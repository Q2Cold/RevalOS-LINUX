#!/bin/bash
set -Eeuo pipefail
trap 'echo "PipeWire остановлен на строке $LINENO"' ERR

if [ "$EUID" -ne 0 ]; then
    echo "Запусти сценарий через su -c."
    exit 1
fi

work=/home/myos/reval-build/kde-deps
helper=/home/myos/reval-build/kde/as-myos.py
archive="$work/pipewire-1.6.8.tar.bz2"
source="$work/pipewire-1.6.8"
build="$work/build-pipewire-1.6.8"

as_user() {
    /usr/bin/python3 "$helper" "$@"
}

if pkg-config --exists libpipewire-0.3; then
    echo "PipeWire уже установлен: $(pkg-config --modversion libpipewire-0.3)"
    exit 0
fi

test -f "$helper"
command -v meson
command -v ninja
test -d "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
      https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.6.8/pipewire-1.6.8.tar.bz2 \
      -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf '9ae75812a76951c93210a26272c90ef3  %s\n' "$archive" |
    md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

if [ ! -f "$build/build.ninja" ]; then
    as_user meson setup "$build" "$source" \
      --prefix=/usr --libdir=lib --buildtype=release \
      '-Dsession-managers=[]'
fi

as_user ninja -C "$build" -j 1
ninja -C "$build" install
/sbin/ldconfig

echo "=== Установленная версия PipeWire ==="
pkg-config --modversion libpipewire-0.3
df -h /
