#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO"' ERR

[ "$EUID" -eq 0 ] || exit 1

work=/home/myos/reval-build/kde-deps
archive="$work/lm-sensors-3-6-2.tar.gz"
source="$work/lm-sensors-3-6-2"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
      https://github.com/hramrach/lm-sensors/archive/V3-6-2/lm-sensors-3-6-2.tar.gz \
      -o "$archive.download"

    printf '44c733f509cd4a31494fd3e355152b0a  %s\n' \
      "$archive.download" | md5sum -c -

    as_user mv "$archive.download" "$archive"
fi

printf '44c733f509cd4a31494fd3e355152b0a  %s\n' \
  "$archive" | md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user make -C "$source" -j1 \
    PREFIX=/usr LIBDIR=/usr/lib \
    BUILD_STATIC_LIB=0 MANDIR=/usr/share/man

make -C "$source" \
    PREFIX=/usr LIBDIR=/usr/lib \
    BUILD_STATIC_LIB=0 MANDIR=/usr/share/man install

/sbin/ldconfig

echo "=== Проверка libsensors ==="
test -r /usr/include/sensors/sensors.h
test -e /usr/lib/libsensors.so
/usr/bin/sensors --version

echo "=== Продолжаем Plasma ==="
bash /home/myos/reval-build/kde/run-plasma.sh first-group.md5
