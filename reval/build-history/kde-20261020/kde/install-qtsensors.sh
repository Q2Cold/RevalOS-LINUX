#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${stage:-подготовка}, строка $LINENO"' ERR

test "$EUID" -eq 0
work=/home/myos/reval-build/qt-6.11.2
package=qtsensors-everywhere-src-6.11.2
archive="$work/$package.tar.xz"
build="$work/build-qtsensors"
checksum=68c8e44dfb32e8e2182f63f5544c2f462089b1bb049574f1d504ee2648903119

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

stage="скачивание Qt Sensors"
as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://download.qt.io/archive/qt/6.11/6.11.2/submodules/$package.tar.xz" \
        -o "$archive.download"
    printf '%s  %s\n' "$checksum" "$archive.download" | sha256sum -c -
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -

if [ ! -d "$work/$package" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

stage="сборка Qt Sensors"
as_user /opt/qt6/bin/qt-cmake \
    -S "$work/$package" -B "$build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_EXAMPLES=OFF

as_user cmake --build "$build" --parallel 1

stage="установка Qt Sensors"
cmake --install "$build"
/sbin/ldconfig

test -f /opt/qt6/lib/cmake/Qt6Sensors/Qt6SensorsConfig.cmake
echo '=== Qt Sensors установлен ==='

stage="третья группа Plasma"
bash /home/myos/reval-build/kde/run-plasma.sh third-group.md5
