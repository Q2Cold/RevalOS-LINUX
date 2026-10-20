#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка установки ModemManager, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps
source="$work/ModemManager-1.24.2"
build="$work/build-ModemManager-1.24.2"
archive="$work/ModemManager-1.24.2.tar.gz"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

pkg-config --modversion gudev-1.0 libxslt
as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/archive/1.24.2/ModemManager-1.24.2.tar.gz \
        -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    b72860c54670f362e947edba160fa98e "$archive" |
    md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

setup_args=()
if [ -f "$build/meson-private/coredata.dat" ]; then
    setup_args+=(--reconfigure)
fi

as_user meson setup "${setup_args[@]}" "$build" "$source" \
    --prefix=/usr \
    --libdir=lib \
    --buildtype=release \
    --wrap-mode=nodownload \
    -Dbash_completion=false \
    -Dqrtr=false \
    -Dmbim=false \
    -Dqmi=false \
    2>&1 | as_user tee "$work/configure-ModemManager.log"

as_user ninja -C "$build" -j1 \
    2>&1 | as_user tee "$work/build-ModemManager.log"

ninja -C "$build" install
/sbin/ldconfig

echo '=== Проверка ModemManager ==='
pkg-config --modversion mm-glib
df -h /
