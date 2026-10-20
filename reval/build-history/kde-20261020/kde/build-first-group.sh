#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO. Пакет: ${package:-подготовка}"' ERR

. /etc/profile.d/qt6.sh

work="$HOME/reval-build/kde/frameworks-6.29.0"
mkdir -p "$work/completed"
cd "$work"

cat > first-group.md5 <<'PACKAGES'
04a8c3e8651fdf4dead94221a3451f93  breeze-icons-6.29.0.tar.xz
cd2fc88992a0da5b7b9bd16288e2f36f  oxygen-icons-6.29.0.tar.xz
04136d69a5f340514fad6352629adb28  attica-6.29.0.tar.xz
e897f5323b32c6bdd477369a61972b2e  karchive-6.29.0.tar.xz
03a439a6c3d78eebd5484cf69c5c41a3  kcodecs-6.29.0.tar.xz
194b8c40c5c7e143b44ee2f8dadae775  kconfig-6.29.0.tar.xz
9513021c1335227ec38b7cc7b92152f2  kcoreaddons-6.29.0.tar.xz
a566661bbfde2500f39c3bfe6fd700e2  kdbusaddons-6.29.0.tar.xz
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

    options=()
    case "$package" in
        breeze-icons-*)
            options+=(-DWITH_ICON_GENERATION=OFF)
            ;;
        oxygen-icons-*)
            if [ ! -f "$source/.reval-scalable-icons" ]; then
                sed -i '/( oxygen/ s/)/scalable )/' "$source/CMakeLists.txt"
                touch "$source/.reval-scalable-icons"
            fi
            ;;
    esac

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
        "${options[@]}" \
        2>&1 | tee "$work/configure-$package.log"

    cmake --build "$build" --parallel 1 \
        2>&1 | tee "$work/build-$package.log"

    printf '\n=== Установка %s — пароль root ===\n' "$package"
    su -c "cmake --install /home/myos/reval-build/kde/frameworks-6.29.0/build-$package && /sbin/ldconfig" </dev/tty

    touch "$work/completed/$package"
    printf '\n=== %s установлен ===\n' "$package"
done < first-group.md5

printf '\n=== Проверка ===\n'
test -f /usr/share/icons/breeze/index.theme
test -f /usr/share/icons/oxygen/index.theme
test -f /usr/lib/cmake/KF6CoreAddons/KF6CoreAddonsConfig.cmake
test -f /usr/lib/cmake/KF6DBusAddons/KF6DBusAddonsConfig.cmake

printf '\n=== Первая группа KDE Frameworks установлена ===\n'
df -h /
