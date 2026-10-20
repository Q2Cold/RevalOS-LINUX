#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка в строке $LINENO. Пакет: ${package:-подготовка}"' ERR

. /etc/profile.d/qt6.sh

work="$HOME/reval-build/kde/frameworks-6.29.0"
mkdir -p "$work/completed"
cd "$work"

cat > third-group.md5 <<'PACKAGES'
ff94c0e5bbdaf953d4615106557e6074  kauth-6.29.0.tar.xz
5ea24f2fb7026f0d63cdba7afb8acac4  kcompletion-6.29.0.tar.xz
eb5be13f4db87848f962f45beadb8911  kcrash-6.29.0.tar.xz
af09e18cebf69e98630e4d06440b5707  kdoctools-6.29.0.tar.xz
64f0223b5b3d8d0c87d5951787a844cf  kpty-6.29.0.tar.xz
1dbc1a568c3991bfd9c8780659c61558  kunitconversion-6.29.0.tar.xz
f316ed426e1df0616143a9f4bc43554a  kcolorscheme-6.29.0.tar.xz
21d71db72c242423c2758c84e8d2ebfd  kconfigwidgets-6.29.0.tar.xz
52d2f3b7108240e1a745a6dd2058eb72  kservice-6.29.0.tar.xz
4d90ee680058f485acf896fa222f0f6b  kglobalaccel-6.29.0.tar.xz
ba00e16aba965de53ed0493d45aba61c  kpackage-6.29.0.tar.xz
b90309874fe6bc26298c4114401bb9ca  kdesu-6.29.0.tar.xz
38c9b27fadd91131092df1ac17484a4b  kiconthemes-6.29.0.tar.xz
95a52444c959d82e83d8506756b1498d  knotifications-6.29.0.tar.xz
d6434be49817654e9d878fa3f8862539  kjobwidgets-6.29.0.tar.xz
32155a4d6ca2ffbb79980b51d034d480  ktextwidgets-6.29.0.tar.xz
43aec19a04194118ade54d584691fe3c  kxmlgui-6.29.0.tar.xz
ab9726b47279b62fba2b02d1be1e7f8e  kbookmarks-6.29.0.tar.xz
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
done < third-group.md5

printf '\n=== Проверка ===\n'
for component in KF6Auth KF6ConfigWidgets KF6Service KF6IconThemes KF6Notifications KF6XmlGui; do
    test -f "/usr/lib/cmake/$component/${component}Config.cmake"
    printf '%s: найден\n' "$component"
done

printf '\n=== Третья группа KDE Frameworks установлена ===\n'
df -h /
