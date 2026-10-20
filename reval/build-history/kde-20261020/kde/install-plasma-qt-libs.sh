#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка: ${package:-подготовка}, строка $LINENO"' ERR

[ "$EUID" -eq 0 ] || {
    echo "Запусти через su -c."
    exit 1
}

work=/home/myos/reval-build/kde-deps
helper=/home/myos/reval-build/kde/as-myos.py

as_user() {
    /usr/bin/python3 "$helper" "$@"
}

echo "=== Проверка работы sassc ==="
result="$(printf '$c: red; .test { color: $c; }\n' |
    as_user /usr/bin/sassc -s -t compressed)"
printf '%s\n' "$result"
[ "$result" = '.test{color:red}' ]

as_user mkdir -p "$work/completed-plasma-deps"

build_package() {
    local archive="$1" checksum="$2" url="$3" prefix="$4"
    shift 4
    package="${archive%.tar.*}"
    local source="$work/$package"
    local build="$work/build-$package"
    local marker="$work/completed-plasma-deps/$package"

    if [ -f "$marker" ]; then
        echo "=== Уже установлен: $package ==="
        return
    fi

    echo "=== Подготовка: $package ==="
    if [ ! -f "$work/$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "$url" -o "$work/$archive.download"
        printf '%s  %s\n' "$checksum" "$work/$archive.download" |
            md5sum -c -
        as_user mv "$work/$archive.download" "$work/$archive"
    fi

    printf '%s  %s\n' "$checksum" "$work/$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        as_user tar -xf "$work/$archive" -C "$work"
    fi

    as_user cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_LIBEXECDIR=libexec \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SKIP_INSTALL_RPATH=ON \
        -DBUILD_TESTING=OFF "$@" \
        2>&1 | as_user tee "$work/configure-$package.log"

    as_user cmake --build "$build" --parallel 1 \
        2>&1 | as_user tee "$work/build-$package.log"

    cmake --install "$build"
    /sbin/ldconfig
    as_user touch "$marker"
    echo "=== Установлен: $package ==="
}

build_package \
    kquickimageeditor-0.6.2.1.tar.gz \
    3ae93b786dfb9e2586f3142cb859d5d8 \
    https://github.com/KDE/kquickimageeditor/archive/v0.6.2.1/kquickimageeditor-0.6.2.1.tar.gz \
    /usr -DWITH_OPENCV=OFF

build_package \
    pulseaudio-qt-1.8.1.tar.xz \
    fa37fbba12097a6ff276f0a29ddec20f \
    https://mirrors.xtom.nl/kde/stable/pulseaudio-qt/pulseaudio-qt-1.8.1.tar.xz \
    /usr

build_package \
    qtkeychain-0.16.0.tar.gz \
    f97ec6ec37a465abdea63c2def01f280 \
    https://github.com/frankosterfeld/qtkeychain/archive/0.16.0/qtkeychain-0.16.0.tar.gz \
    /opt/qt6 -DBUILD_WITH_QT6=ON

build_package \
    kirigami-addons-1.13.1.tar.xz \
    d3a1944cb0dddcea3f441f04ee54c0d0 \
    https://mirrors.xtom.nl/kde/stable/kirigami-addons/kirigami-addons-1.13.1.tar.xz \
    /usr

echo "=== Четыре компонента установлены ==="
df -h /
