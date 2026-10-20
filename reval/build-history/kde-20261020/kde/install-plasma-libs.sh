#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено на строке $LINENO"' ERR

if [ "$EUID" -ne 0 ]; then
    echo "Запусти сценарий через su -c."
    exit 1
fi

work=/home/myos/reval-build/kde-deps
helper=/home/myos/reval-build/kde/as-myos.py

as_user() {
    /usr/bin/python3 "$helper" "$@"
}

fetch() {
    local file="$1" checksum="$2" url="$3"

    if [ ! -f "$work/$file" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "$url" -o "$work/$file.download"
        printf '%s  %s\n' "$checksum" "$work/$file.download" |
            md5sum -c -
        as_user mv "$work/$file.download" "$work/$file"
    fi

    printf '%s  %s\n' "$checksum" "$work/$file" | md5sum -c -
}

unpack() {
    local file="$1" directory="$2"
    if [ ! -d "$work/$directory" ]; then
        as_user tar -xf "$work/$file" -C "$work"
    fi
}

test -f "$helper"
test -d "$work"

if [ ! -f /usr/share/hwdata/pnp.ids ]; then
    echo "=== hwdata ==="
    fetch hwdata-0.410.tar.gz \
      07f1de937ff5b830280f6157221164eb \
      https://github.com/vcrhonek/hwdata/archive/v0.410/hwdata-0.410.tar.gz
    unpack hwdata-0.410.tar.gz hwdata-0.410
    as_user /bin/sh -c 'cd "$1"; exec ./configure --prefix=/usr --disable-blacklist' \
      sh "$work/hwdata-0.410"
    make -C "$work/hwdata-0.410" install
fi

if ! pkg-config --exists libdisplay-info; then
    echo "=== libdisplay-info ==="
    fetch libdisplay-info-0.4.0.tar.xz \
      af9f07493bd5ff560a98b95ea4c5c129 \
      https://gitlab.freedesktop.org/emersion/libdisplay-info/-/releases/0.4.0/downloads/libdisplay-info-0.4.0.tar.xz
    unpack libdisplay-info-0.4.0.tar.xz libdisplay-info-0.4.0
    if [ ! -f "$work/build-libdisplay-info/build.ninja" ]; then
        as_user meson setup "$work/build-libdisplay-info" \
          "$work/libdisplay-info-0.4.0" \
          --prefix=/usr --libdir=lib --buildtype=release
    fi
    as_user ninja -C "$work/build-libdisplay-info" -j 1
    ninja -C "$work/build-libdisplay-info" install
    /sbin/ldconfig
fi

if [ ! -f /usr/include/utf8cpp/utf8.h ]; then
    echo "=== utfcpp ==="
    fetch utfcpp-4.1.1.tar.gz \
      2b439bf8f222cd85bac0d2603265a246 \
      https://github.com/nemtrif/utfcpp/archive/v4.1.1/utfcpp-4.1.1.tar.gz
    unpack utfcpp-4.1.1.tar.gz utfcpp-4.1.1
    as_user cmake -S "$work/utfcpp-4.1.1" -B "$work/build-utfcpp" \
      -DCMAKE_INSTALL_PREFIX=/usr
    cmake --install "$work/build-utfcpp"
fi

if [ ! -f /usr/include/taglib/tag.h ]; then
    echo "=== TagLib ==="
    fetch taglib-2.3.1.tar.gz \
      b189dcfcf284179c04b97a89887e0ce6 \
      https://taglib.org/releases/taglib-2.3.1.tar.gz
    unpack taglib-2.3.1.tar.gz taglib-2.3.1
    as_user cmake -S "$work/taglib-2.3.1" -B "$work/build-taglib" \
      -G Ninja -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON
    as_user cmake --build "$work/build-taglib" --parallel 1
    cmake --install "$work/build-taglib"
    /sbin/ldconfig
fi

if ! pkg-config --exists libqalculate; then
    echo "=== libqalculate ==="
    pkg-config --exists libcurl icu-uc libxml-2.0 || {
        echo "Для libqalculate пока не хватает libcurl, ICU или libxml2."
        exit 1
    }
    fetch libqalculate-5.12.0.tar.gz \
      46f93f638b6ce747f17dba955f95c9cf \
      https://github.com/Qalculate/libqalculate/releases/download/v5.12.0/libqalculate-5.12.0.tar.gz
    unpack libqalculate-5.12.0.tar.gz libqalculate-5.12.0
    as_user /bin/sh -c \
      'cd "$1"; exec ./configure --prefix=/usr --disable-static' \
      sh "$work/libqalculate-5.12.0"
    as_user make -C "$work/libqalculate-5.12.0" -j 1
    make -C "$work/libqalculate-5.12.0" install
    rm -f /usr/lib/libqalculate.la
    /sbin/ldconfig
fi

if ! command -v xdotool >/dev/null 2>&1; then
    echo "=== xdotool ==="
    fetch xdotool-4.20260303.1.tar.gz \
      fc6864ebb381f8b50c37e2d46dbd37b1 \
      https://github.com/jordansissel/xdotool/archive/v4.20260303.1/xdotool-4.20260303.1.tar.gz
    unpack xdotool-4.20260303.1.tar.gz xdotool-4.20260303.1
    as_user make -C "$work/xdotool-4.20260303.1" \
      WITHOUT_RPATH_FIX=1 -j 1
    make -C "$work/xdotool-4.20260303.1" \
      PREFIX=/usr INSTALLMAN=/usr/share/man install
    /sbin/ldconfig
fi

echo "=== Проверка ==="
for package in libdisplay-info libqalculate libpipewire-0.3; do
    printf '%-20s ' "$package"
    pkg-config --modversion "$package"
done
command -v xdotool
df -h /
