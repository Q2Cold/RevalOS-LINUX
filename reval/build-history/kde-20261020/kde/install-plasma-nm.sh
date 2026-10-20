#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка сборки plasma-nm, строка $LINENO"' ERR

test "$EUID" -eq 0
work=/home/myos/reval-build/kde/plasma-6.7.4
package=plasma-nm-6.7.4
source="$work/$package"
build="$work/build-$package"
archive="$work/$package.tar.xz"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work/logs"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://mirrors.xtom.nl/kde/stable/plasma/6.7.4/$package.tar.xz" \
        -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    2dd1ab12f435d709e055b635629f5c14 "$archive" |
    md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user cmake -S "$source" -B "$build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_LIBEXECDIR=libexec \
    -DKDE_INSTALL_SYSCONFDIR=/etc \
    -DCMAKE_PREFIX_PATH=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DBUILD_TESTING=OFF \
    -DDISABLE_MODEMMANAGER_SUPPORT=ON \
    2>&1 | as_user tee "$work/logs/configure-$package.log"

as_user cmake --build "$build" --parallel 1 \
    2>&1 | as_user tee "$work/logs/build-$package.log"

cmake --install "$build"
/sbin/ldconfig

echo '=== plasma-nm установлен ==='
test -f /usr/lib/plugins/plasma/applets/org.kde.plasma.networkmanagement.so
df -h /
