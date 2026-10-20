#!/bin/bash
set -Eeuo pipefail
trap 'echo "Остановлено: ${package:-подготовка}, строка $LINENO"' ERR

[ "$EUID" -eq 0 ] || {
    echo "Запусти через su -c."
    exit 1
}

work=/home/myos/reval-build/kde/plasma-6.7.4
manifest="${1:?Укажи список пакетов}"

case "$manifest" in
    first-group.md5|second-group.md5|third-group.md5|fourth-group.md5|fifth-group.md5|sixth-group.md5|seventh-group.md5) ;;
    *) echo "Неизвестный список: $manifest"; exit 1 ;;
esac

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py \
      /usr/bin/env \
      PATH=/opt/rustc/bin:/opt/qt6/bin:/usr/local/bin:/usr/bin:/bin \
      "$@"
}

test -r "$work/$manifest"
as_user mkdir -p "$work/completed" "$work/logs"

while read -r checksum archive; do
    [[ "$checksum" =~ ^[[:xdigit:]]{32}$ ]]
    [[ "$archive" =~ ^[a-z0-9-]+-6\.7\.4\.tar\.xz$ ]]

    package="${archive%.tar.xz}"
    source="$work/$package"
    build="$work/build-$package"

    if [ -f "$work/completed/$package" ]; then
        echo "=== Уже установлен: $package ==="
        continue
    fi

    echo "=== Загрузка: $package ==="
    if [ ! -f "$work/$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
          "https://mirrors.xtom.nl/kde/stable/plasma/6.7.4/$archive" \
          -o "$work/$archive.download"

        printf '%s  %s\n' "$checksum" "$work/$archive.download" |
            md5sum -c -
        as_user mv "$work/$archive.download" "$work/$archive"
    fi

    printf '%s  %s\n' "$checksum" "$work/$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        as_user tar -xf "$work/$archive" -C "$work"
    fi

    echo "=== Настройка: $package ==="
    as_user cmake -S "$source" -B "$build" -G Ninja \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_INSTALL_LIBEXECDIR=libexec \
      -DKDE_INSTALL_SYSCONFDIR=/etc \
      -DCMAKE_PREFIX_PATH=/opt/qt6 \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_SKIP_INSTALL_RPATH=ON \
      -DBUILD_QT5=OFF \
      -DBUILD_TESTING=OFF \
      2>&1 | as_user tee "$work/logs/configure-$package.log"

    echo "=== Сборка: $package ==="
    as_user cmake --build "$build" --parallel 1 \
      2>&1 | as_user tee "$work/logs/build-$package.log"

    echo "=== Установка: $package ==="
    cmake --install "$build"
    /sbin/ldconfig

    as_user touch "$work/completed/$package"
    echo "=== Установлен: $package ==="
done < "$work/$manifest"

echo "=== Группа Plasma установлена: $manifest ==="
df -h /
