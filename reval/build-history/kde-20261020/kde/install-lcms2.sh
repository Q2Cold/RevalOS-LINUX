#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено, строка $LINENO"' ERR

test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps
package=lcms2-2.19.1
archive="$work/$package.tar.gz"
source="$work/$package"
build="$work/build-$package"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://github.com/mm2/Little-CMS/releases/download/lcms2.19.1/$package.tar.gz" \
        -o "$archive.download"

    printf '%s  %s\n' \
        541978f73749499e9e0277bfe5a3c868 \
        "$archive.download" | md5sum -c -

    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    541978f73749499e9e0277bfe5a3c868 \
    "$archive" | md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

if [ -f "$build/build.ninja" ]; then
    as_user meson setup --reconfigure "$build" "$source" \
        --prefix=/usr --libdir=lib --buildtype=release
else
    as_user meson setup "$build" "$source" \
        --prefix=/usr --libdir=lib --buildtype=release
fi

as_user ninja -C "$build" -j1
ninja -C "$build" install
/sbin/ldconfig

echo '=== Проверка Little CMS ==='
as_user pkg-config --modversion lcms2

echo '=== Продолжаем третью группу Plasma ==='
bash /home/myos/reval-build/kde/run-plasma.sh third-group.md5
