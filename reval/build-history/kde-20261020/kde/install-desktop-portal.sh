#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: xdg-desktop-portal, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps
package=xdg-desktop-portal-1.22.1
archive="$work/$package.tar.xz"
source="$work/$package"
build="$work/build-$package"
checksum=edfbfffe55a35920a303404b6c5d49a0

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://github.com/flatpak/xdg-desktop-portal/releases/download/1.22.1/$package.tar.xz" \
        -o "$archive.download"
    printf '%s  %s\n' "$checksum" "$archive.download" | md5sum -c -
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

options=()
if [ -f "$build/build.ninja" ]; then
    options+=(--reconfigure)
fi

as_user meson setup "${options[@]}" "$build" "$source" \
    --prefix=/usr \
    --libdir=lib \
    --libexecdir=libexec \
    --buildtype=release \
    -Dtests=disabled

as_user ninja -C "$build" -j1
ninja -C "$build" install
/sbin/ldconfig

echo '=== xdg-desktop-portal установлен ==='
test -x /usr/libexec/xdg-desktop-portal
ls -l /usr/libexec/xdg-desktop-portal \
      /usr/libexec/xdg-document-portal
df -h /
