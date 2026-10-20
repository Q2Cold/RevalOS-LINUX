#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO."' ERR
[ "$EUID" -eq 0 ] || { echo "Запусти через su."; exit 1; }

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

archive="$work/phonon-4.12.0.tar.xz"
if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 \
      https://mirrors.xtom.nl/kde/stable/phonon/4.12.0/phonon-4.12.0.tar.xz \
      -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf 'e80e9c73967080016bdb3c0ee514ceab  %s\n' "$archive" |
    md5sum -c -

if [ ! -d "$work/phonon-4.12.0" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user cmake -S "$work/phonon-4.12.0" \
    -B "$work/build-phonon" -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_PREFIX_PATH=/opt/qt6 \
    -DCMAKE_BUILD_TYPE=Release \
    -DPHONON_BUILD_QT5=OFF \
    -DPHONON_BUILD_QT6=ON \
    -DBUILD_TESTING=OFF \
    2>&1 | as_user tee "$work/configure-phonon.log"

as_user cmake --build "$work/build-phonon" --parallel 1 \
    2>&1 | as_user tee "$work/build-phonon.log"

cmake --install "$work/build-phonon"
/sbin/ldconfig
echo "=== Phonon установлен ==="

bash /home/myos/reval-build/kde/run-frameworks.sh sixth-group.md5

printf '\n=== Зависимости Plasma: доступность через pkg-config ===\n'
for package in libdisplay-info pwquality libqalculate libnl-3.0 \
               libxcvt libpipewire-0.3 libpulse taglib opencv4 \
               tesseract libwacom avahi-client bluez mm-glib; do
    printf '%-24s ' "$package"
    as_user pkg-config --modversion "$package" 2>/dev/null ||
        printf 'не определяется\n'
done

printf '\n=== Инструменты ===\n'
for tool in rustc cargo sassc xdotool; do
    printf '%-12s ' "$tool"
    as_user /bin/sh -c 'command -v "$1"' check "$tool" ||
        printf 'не найден\n'
done

printf '\n=== Место ===\n'
df -h /
