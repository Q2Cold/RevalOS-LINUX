#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO. Пакет: ${package:-подготовка}"' ERR

. /etc/profile.d/qt6.sh

work="$HOME/reval-build/kde/frameworks-6.29.0"
mkdir -p "$work/completed"
cd "$work"

cat > fifth-group.md5 <<'PACKAGES'
b3d793178f7c51b5b5cec6ef5c47c186  syndication-6.29.0.tar.xz
807986b129cdab88939191fc8c3f11d9  knewstuff-6.29.0.tar.xz
233ebeb1da81ad27819f61aa6adb3b3b  frameworkintegration-6.29.0.tar.xz
10caf984c5962c1f28a733a5e6e88bc5  kparts-6.29.0.tar.xz
1b572fc268b2a120734889176449b654  syntax-highlighting-6.29.0.tar.xz
1ac31cccd071ea20a3a01fbc5c328ffc  krunner-6.29.0.tar.xz
24db2c46e60ef7354a915f36c4b10d9e  prison-6.29.0.tar.xz
4ab0da283adbfdb5e1ae48bf03d63871  qqc2-desktop-style-6.29.0.tar.xz
74e7b660e4f6993cd95e9fd961e34d0b  kholidays-6.29.0.tar.xz
de97d121b2f24c03e9bce05edb7a6294  kcalendarcore-6.29.0.tar.xz
b7c39a611d24d8083014dfbb69c41d99  kquickcharts-6.29.0.tar.xz
73c667bd31a69d3f5b24dac9f5b9f9cc  kdav-6.29.0.tar.xz
5fcdedf1670d11de1ef3ed3ee0195802  kstatusnotifieritem-6.29.0.tar.xz
8ae0ac197fffbc36dc1fba0634d3b0c9  ksvg-6.29.0.tar.xz
f382cd12656952d85178985ae92be71b  ktexttemplate-6.29.0.tar.xz
182e7df4d6a35c2e0dd0cf9f50d99b85  kuserfeedback-6.29.0.tar.xz
8163ee41e712b70f72a52f6547975e35  kmime-6.29.0.tar.xz
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
done < fifth-group.md5

printf '\n=== Проверка ===\n'
for component in KF6NewStuff KF6Parts KF6Runner KF6Svg KF6CalendarCore; do
    test -f "/usr/lib/cmake/$component/${component}Config.cmake"
    printf '%s: найден\n' "$component"
done

printf '\n=== Пятая группа KDE Frameworks установлена ===\n'
df -h /
