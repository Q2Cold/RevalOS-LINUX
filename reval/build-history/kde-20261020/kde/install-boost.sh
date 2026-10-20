#!/bin/bash
set -Eeuo pipefail
trap 'echo "Boost: ошибка в строке $LINENO"' ERR

[ "$EUID" -eq 0 ] || {
    echo "Запусти через su -c."
    exit 1
}

work=/home/myos/reval-build/kde-deps
archive="$work/boost-1.92.0-b2-nodocs.tar.xz"
source="$work/boost-1.92.0"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
      https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-b2-nodocs.tar.xz \
      -o "$archive.download"

    printf '01f7ba6534c21e1b49dc9f69524bf5e4  %s\n' \
      "$archive.download" | md5sum -c -

    as_user mv "$archive.download" "$archive"
fi

printf '01f7ba6534c21e1b49dc9f69524bf5e4  %s\n' \
  "$archive" | md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

echo "=== Подготовка Boost ==="
as_user /bin/bash -c '
    set -e
    cd "$1"
    ./bootstrap.sh --prefix=/usr --libdir=/usr/lib \
        --with-python=python3
' reval-build "$source"

echo "=== Сборка Boost ==="
as_user /bin/bash -c '
    set -e
    cd "$1"
    ./b2 stage -j1 variant=release threading=multi link=shared
' reval-build "$source" \
    2>&1 | as_user tee "$work/build-boost-1.92.0.log"

echo "=== Установка Boost ==="
(
    cd "$source"
    ./b2 install -j1 variant=release threading=multi link=shared
)

/sbin/ldconfig

echo "=== Проверка Boost ==="
grep '^#define BOOST_LIB_VERSION ' /usr/include/boost/version.hpp
test -f /usr/lib/cmake/Boost-1.92.0/BoostConfig.cmake
echo "Конфигурация Boost для CMake установлена."
df -h /
