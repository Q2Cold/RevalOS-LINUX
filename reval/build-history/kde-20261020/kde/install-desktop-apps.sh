#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR

test "$EUID" -eq 0
work=/home/myos/reval-build/kde/apps-26.04.3
helper=/home/myos/reval-build/kde/as-myos.py
test -f "$helper"

as_user() {
    /usr/bin/python3 "$helper" "$@"
}

as_user mkdir -p "$work/completed" "$work/logs"

while read -r checksum name; do
    package="$name-26.04.3"
    archive="$work/$package.tar.xz"
    source="$work/$package"
    build="$work/build-$package"

    if [ -f "$work/completed/$package" ]; then
        echo "=== Уже установлен: $package ==="
        continue
    fi

    echo "=== Загрузка: $package ==="
    if [ ! -f "$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "https://mirrors.xtom.nl/kde/stable/release-service/26.04.3/src/$package.tar.xz" \
            -o "$archive.download"
        as_user mv "$archive.download" "$archive"
    fi

    printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

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
        2>&1 | as_user tee "$work/logs/configure-$package.log"

    as_user cmake --build "$build" --parallel 1 \
        2>&1 | as_user tee "$work/logs/build-$package.log"

    echo "=== Установка: $package ==="
    cmake --install "$build"
    /sbin/ldconfig
    as_user touch "$work/completed/$package"

    echo "=== Установлен: $package ==="
done <<'PACKAGES'
4b71ab15411e01ba88c94017731221cd konsole
d16879ed6c66dbaff6e9123916c781c0 dolphin
PACKAGES

echo '=== Проверка установленных программ ==='
test -x /usr/bin/konsole
test -x /usr/bin/dolphin
ls -lh /usr/bin/konsole /usr/bin/dolphin
df -h /
