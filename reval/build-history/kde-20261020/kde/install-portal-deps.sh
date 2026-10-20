#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"

build_package() {
    package="$1"
    local extension="$2" url="$3" checksum="$4"
    local archive="$work/$package.$extension"
    local source="$work/$package"
    local build="$work/build-$package"

    if [ ! -f "$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "$url" -o "$archive.download"
        printf '%s  %s\n' "$checksum" "$archive.download" | md5sum -c -
        as_user mv "$archive.download" "$archive"
    fi

    printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        as_user tar -xf "$archive" -C "$work"
    fi

    if [ "$package" = fuse-3.18.2 ]; then
        # Поправка BLFS: не устанавливать лишние загрузочные правила.
        as_user sed -i '/^udev/,$ s/^/#/' "$source/util/meson.build"
    fi

    local options=()
    if [ -f "$build/build.ninja" ]; then
        options+=(--reconfigure)
    fi

    as_user meson setup "${options[@]}" "$build" "$source" \
        --prefix=/usr --libdir=lib --buildtype=release
    as_user ninja -C "$build" -j1
    ninja -C "$build" install
    /sbin/ldconfig

    if [ "$package" = fuse-3.18.2 ]; then
        chmod u+s /usr/bin/fusermount3
    fi

    echo "=== Установлен: $package ==="
}

build_package fuse-3.18.2 tar.gz \
    https://github.com/libfuse/libfuse/releases/download/fuse-3.18.2/fuse-3.18.2.tar.gz \
    43c6f6cd2c1368d916f6fb080eb39cbb

build_package bubblewrap-0.11.2 tar.xz \
    https://github.com/containers/bubblewrap/releases/download/v0.11.2/bubblewrap-0.11.2.tar.xz \
    6376255e2e505100e01b20c2dafa7faf

echo '=== Проверка установленных компонентов ==='
as_user pkg-config --modversion fuse3
/usr/bin/bwrap --version

echo '=== Проверка изоляции от имени myos ==='
as_user /usr/bin/bwrap --ro-bind / / --unshare-user /usr/bin/true

echo '=== Поддержка FUSE в ядре ==='
/sbin/modprobe fuse
test -c /dev/fuse
ls -l /dev/fuse

df -h /
