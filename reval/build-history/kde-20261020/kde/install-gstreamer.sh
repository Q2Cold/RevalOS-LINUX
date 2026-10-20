#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py \
        /usr/bin/env \
        PATH=/opt/rustc/bin:/opt/qt6/bin:/usr/local/bin:/usr/bin:/bin \
        "$@"
}

as_user mkdir -p "$work"

build_package() {
    local name="$1" checksum="$2"
    package="$name-1.28.6"
    local archive="$work/$package.tar.xz"
    local source="$work/$package"
    local build="$work/build-$package"

    if [ ! -f "$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "https://gstreamer.freedesktop.org/src/$name/$package.tar.xz" \
            -o "$archive.download"
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
        --prefix=/usr \
        --libdir=lib \
        --libexecdir=libexec \
        --buildtype=release \
        --wrap-mode=nodownload \
        -Dtests=disabled \
        -Dexamples=disabled

    as_user ninja -C "$build" -j1
    ninja -C "$build" install
    /sbin/ldconfig

    echo "=== Установлен: $package ==="
}

build_package gstreamer \
    3d16d7912727ea85ab90b9e5f3bc6e8a

build_package gst-plugins-base \
    cd0b2bd13e8196d5bfb20459c12a5d9b

echo '=== Проверка библиотек ==='
as_user pkg-config --modversion \
    gstreamer-1.0 \
    gstreamer-base-1.0 \
    gstreamer-video-1.0 \
    gstreamer-pbutils-1.0

package=xdg-desktop-portal
echo '=== Продолжаем установку портала ==='
bash /home/myos/reval-build/kde/install-desktop-portal.sh
