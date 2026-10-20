#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"
as_user pkg-config --exists libevdev

build_package() {
    package="$1"
    local url="$2" checksum="$3"
    shift 3
    local archive="$work/$package.tar.xz"
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

    local options=()
    if [ -f "$build/build.ninja" ]; then
        options+=(--reconfigure)
    fi

    as_user meson setup "${options[@]}" "$build" "$source" \
        --prefix=/usr --libdir=lib --buildtype=release "$@"
    as_user ninja -C "$build" -j1
    ninja -C "$build" install
    /sbin/ldconfig
    echo "=== Установлен: $package ==="
}

if ! as_user pkg-config --exists gudev-1.0; then
    build_package libgudev-238 \
        https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz \
        46da30a1c69101c3a13fa660d9ab7b73
fi

build_package libwacom-2.19.1 \
    https://github.com/linuxwacom/libwacom/releases/download/libwacom-2.19.1/libwacom-2.19.1.tar.xz \
    83baa1eb388d506b670d13a8a18ff224 \
    -Dtests=disabled

echo '=== Проверка ==='
as_user pkg-config --modversion gudev-1.0 libwacom
df -h /
