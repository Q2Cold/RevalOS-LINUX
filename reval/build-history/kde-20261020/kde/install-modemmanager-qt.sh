#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка, строка $LINENO"' ERR
test "$EUID" -eq 0

work=/home/myos/reval-build/kde/frameworks-6.29.0
package=modemmanager-qt-6.29.0
archive="$work/$package.tar.xz"
source="$work/$package"
build="$work/build-$package"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

pkg-config --modversion mm-glib

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://mirrors.xtom.nl/kde/stable/frameworks/6.29/$package.tar.xz" \
        -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    3bbc95743bf4670bdd23d3c092483bf9 "$archive" |
    md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user cmake -S "$source" -B "$build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_LIBDIR=lib \
    -DKDE_INSTALL_LIBEXECDIR=libexec \
    -DKDE_INSTALL_SYSCONFDIR=/etc \
    -DCMAKE_PREFIX_PATH=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DBUILD_TESTING=OFF \
    2>&1 | as_user tee "$work/configure-$package.log"

as_user cmake --build "$build" --parallel 1 \
    2>&1 | as_user tee "$work/build-$package.log"

cmake --install "$build"
/sbin/ldconfig

test -f /usr/lib/cmake/KF6ModemManagerQt/KF6ModemManagerQtConfig.cmake
echo '=== ModemManagerQt установлен ==='

echo '=== Продолжение сборки plasma-nm ==='
bash /home/myos/reval-build/kde/install-plasma-nm.sh
