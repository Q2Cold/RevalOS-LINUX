#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка установки Qt Virtual Keyboard, строка $LINENO"' ERR

test "$EUID" -eq 0

work=/home/myos/reval-build/qt-6.11.2
package=qtvirtualkeyboard-everywhere-src-6.11.2
archive="$work/$package.tar.xz"
build="$work/build-qtvirtualkeyboard"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

as_user mkdir -p "$work"

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        "https://download.qt.io/archive/qt/6.11/6.11.2/submodules/$package.tar.xz" \
        -o "$archive.download"

    printf '%s  %s\n' \
        4c6a26734a5c4e4acd5ff9ae5f192a5b883bc4514118f9df2fcf12064e647c2f \
        "$archive.download" | sha256sum -c -

    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    4c6a26734a5c4e4acd5ff9ae5f192a5b883bc4514118f9df2fcf12064e647c2f \
    "$archive" | sha256sum -c -

if [ ! -d "$work/$package" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user /opt/qt6/bin/qt-cmake \
    -S "$work/$package" -B "$build" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_EXAMPLES=OFF

as_user cmake --build "$build" --parallel 1
cmake --install "$build"
/sbin/ldconfig

test -f /opt/qt6/lib/cmake/Qt6VirtualKeyboard/Qt6VirtualKeyboardConfig.cmake
echo '=== Qt Virtual Keyboard установлен ==='

bash /home/myos/reval-build/kde/run-plasma.sh third-group.md5
