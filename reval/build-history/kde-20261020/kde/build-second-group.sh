#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO. Пакет: ${package:-подготовка}"' ERR

. /etc/profile.d/qt6.sh

work="$HOME/reval-build/kde/frameworks-6.29.0"
mkdir -p "$work/completed"
cd "$work"

cat > second-group.md5 <<'PACKAGES'
9f1d2a5324752fc1e376f1a44d82e59f  kguiaddons-6.29.0.tar.xz
e15d397fe3e5d6a17f16c04d0a013e04  ki18n-6.29.0.tar.xz
212c502ef7cf38f31ec3aea352a7e401  kidletime-6.29.0.tar.xz
791f33fe494e4295e411b3ecd5920015  kimageformats-6.29.0.tar.xz
eda9e59655995a0e037a3bc42eb1a9e8  kitemmodels-6.29.0.tar.xz
82038eec5c422b3b138507ab8964ad9e  kitemviews-6.29.0.tar.xz
356da5eb2050defa1aed5c206eb834c0  kplotting-6.29.0.tar.xz
ced1d43c0ca814defbca2a91ed700fcc  kwidgetsaddons-6.29.0.tar.xz
d996373ba3aeda5299c92d9b9f05244a  kwindowsystem-6.29.0.tar.xz
0348f0661a6c347f02a7416acdfa5aec  networkmanager-qt-6.29.0.tar.xz
7098fdaa4c55a369813a70a2c952a7cc  solid-6.29.0.tar.xz
1d4ad3f264af279d92a0d7228726bda3  sonnet-6.29.0.tar.xz
3e14a2b5cb689cc9583f4d9838e2c1e2  threadweaver-6.29.0.tar.xz
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
done < second-group.md5

printf '\n=== Проверка ===\n'
for component in KF6GuiAddons KF6I18n KF6WindowSystem KF6NetworkManagerQt KF6Solid; do
    test -f "/usr/lib/cmake/$component/${component}Config.cmake"
    printf '%s: найден\n' "$component"
done

printf '\n=== Вторая группа KDE Frameworks установлена ===\n'
df -h /
