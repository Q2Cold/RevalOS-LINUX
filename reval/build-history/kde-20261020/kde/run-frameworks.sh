#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR

if [ "$EUID" -ne 0 ]; then
    echo "Этот сценарий запускается через su."
    exit 1
fi

work=/home/myos/reval-build/kde/frameworks-6.29.0
manifest="${1:?Укажи список пакетов}"

case "$manifest" in
    first-group.md5|second-group.md5|third-group.md5|fourth-group.md5|fifth-group.md5|sixth-group.md5) ;;
    *) echo "Неизвестный список пакетов"; exit 1 ;;
esac

command -v python3 >/dev/null
cd "$work"
test -r "$manifest"

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

while read -r checksum archive; do
    [[ "$checksum" =~ ^[[:xdigit:]]{32}$ ]]
    [[ "$archive" =~ ^[a-z0-9-]+-6\.29\.0\.tar\.xz$ ]]

    package="${archive%.tar.xz}"
    source="$work/$package"
    build="$work/build-$package"

    if [ -f "$work/completed/$package" ]; then
        echo "=== Уже установлен: $package ==="
        continue
    fi

    echo "=== Подготовка: $package ==="

    if [ ! -f "$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
          "https://mirrors.xtom.nl/kde/stable/frameworks/6.29/$archive" \
          -o "$archive.download"
        as_user mv "$archive.download" "$archive"
    fi

    printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        as_user tar -xf "$archive"
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
        -DBUILD_PYTHON_BINDINGS=OFF \
        2>&1 | as_user tee "$work/configure-$package.log"

    as_user cmake --build "$build" --parallel 1 \
        2>&1 | as_user tee "$work/build-$package.log"

    echo "=== Установка: $package ==="
    cmake --install "$build"
    /sbin/ldconfig

    as_user touch "$work/completed/$package"
    echo "=== Установлен: $package ==="
done < "$manifest"

echo "=== Все пакеты выбранного списка установлены ==="
df -h /
