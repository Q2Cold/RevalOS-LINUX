#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO. Пакет: ${package:-подготовка}"' ERR

. /etc/profile.d/qt6.sh

work="$HOME/reval-build/kde/frameworks-6.29.0"
mkdir -p "$work/completed"
cd "$work"

cat > fourth-group.md5 <<'PACKAGES'
87babe498d81765fe042f334e5af63fe  kwallet-6.29.0.tar.xz
2a8f180ed2a5ce15f0652c71a0250bbd  kded-6.29.0.tar.xz
f8c4b4fa54a4e4ab590b7eb2303bf383  kio-6.29.0.tar.xz
eb444e38b4fd327c22d34486f21b42b6  kdeclarative-6.29.0.tar.xz
e3ea9add856c983ae55a5e88675f5cd9  kirigami-6.29.0.tar.xz
47eb021fa35e71e4f73bff439748f0cc  kcmutils-6.29.0.tar.xz
PACKAGES

while read -r checksum archive; do
    package="${archive%.tar.xz}"
    source="$work/$package"
    build="$work/build-$package"

    if [ -f "$work/completed/$package" ]; then
        printf '\n=== Уже установлен: %s ===\n' "$package"
        continue
    fi

    printf '\n=== Подготовка %s ===\n' "$package"

    if [ ! -f "$archive" ]; then
        curl -fL --retry 3 \
          "https://mirrors.xtom.nl/kde/stable/frameworks/6.29/$archive" \
          -o "$archive.download"
        mv "$archive.download" "$archive"
    fi

    printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        tar -xf "$archive"
    fi

    cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_LIBEXECDIR=libexec \
        -DKDE_INSTALL_SYSCONFDIR=/etc \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SKIP_INSTALL_RPATH=ON \
        -DBUILD_TESTING=OFF \
        -DBUILD_PYTHON_BINDINGS=OFF \
        2>&1 | tee "$work/configure-$package.log"

    cmake --build "$build" --parallel 1 \
        2>&1 | tee "$work/build-$package.log"

    printf '\n=== Установка %s — пароль root ===\n' "$package"
    su -c "cmake --install /home/myos/reval-build/kde/frameworks-6.29.0/build-$package && /sbin/ldconfig" </dev/tty

    touch "$work/completed/$package"
    printf '\n=== %s установлен ===\n' "$package"
done < fourth-group.md5

printf '\n=== Проверка ===\n'
for component in KF6Wallet KF6KIO KF6Declarative KF6Kirigami KF6KCMUtils; do
    test -f "/usr/lib/cmake/$component/${component}Config.cmake"
    printf '%s: найден\n' "$component"
done

printf '\n=== Четвёртая группа KDE Frameworks установлена ===\n'
df -h /
