#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO"' ERR

[ "$EUID" -eq 0 ] || exit 1

work=/home/myos/reval-build/qt-6.11.2
archive="$work/qtpositioning-everywhere-src-6.11.2.tar.xz"
source="$work/qtpositioning-everywhere-src-6.11.2"
build="$work/build-qtpositioning"
checksum=d8cf15ad43a3b1520adac64cec5900028525cf75f01a4c82a0002e7ac1ae7499

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
      https://download.qt.io/archive/qt/6.11/6.11.2/submodules/qtpositioning-everywhere-src-6.11.2.tar.xz \
      -o "$archive.download"

    printf '%s  %s\n' "$checksum" "$archive.download" | sha256sum -c -
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user /opt/qt6/bin/qt-cmake \
    -S "$source" -B "$build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_EXAMPLES=OFF \
    2>&1 | as_user tee "$work/configure-qtpositioning.log"

as_user cmake --build "$build" --parallel 1 \
    2>&1 | as_user tee "$work/build-qtpositioning.log"

cmake --install "$build"
/sbin/ldconfig

echo "=== Проверка Qt Positioning ==="
test -f /opt/qt6/lib/cmake/Qt6Positioning/Qt6PositioningConfig.cmake
as_user pkg-config --modversion Qt6Positioning

echo "=== Продолжаем вторую группу Plasma ==="
bash /home/myos/reval-build/kde/run-plasma.sh second-group.md5
