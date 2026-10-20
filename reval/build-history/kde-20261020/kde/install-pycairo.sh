#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO"' ERR

[ "$EUID" -eq 0 ] || exit 1

work=/home/myos/reval-build/kde-deps
archive="$work/pycairo-1.29.1.tar.gz"
source="$work/pycairo-1.29.1"
build="$work/build-pycairo-1.29.1"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
      https://github.com/pygobject/pycairo/releases/download/v1.29.1/pycairo-1.29.1.tar.gz \
      -o "$archive.download"

    printf 'fc7c3b4104e88df7dea34af4314b9d12  %s\n' \
      "$archive.download" | md5sum -c -

    as_user mv "$archive.download" "$archive"
fi

printf 'fc7c3b4104e88df7dea34af4314b9d12  %s\n' \
  "$archive" | md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

if [ ! -f "$build/build.ninja" ]; then
    as_user meson setup "$build" "$source" \
      --prefix=/usr --libdir=lib --buildtype=release
fi

as_user ninja -C "$build" -j1
ninja -C "$build" install

echo "=== Проверка Pycairo ==="
as_user /usr/bin/python3 -c \
  'import cairo; print("Pycairo:", cairo.version); print("Модуль:", cairo.__file__)'

echo "=== Продолжаем Plasma ==="
bash /home/myos/reval-build/kde/run-plasma.sh first-group.md5
