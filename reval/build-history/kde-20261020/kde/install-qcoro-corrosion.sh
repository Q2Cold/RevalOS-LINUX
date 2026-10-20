#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка: ${package:-подготовка}, строка $LINENO"' ERR

[ "$EUID" -eq 0 ] || {
    echo "Запусти через su -c."
    exit 1
}

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py \
      /usr/bin/env \
      PATH=/opt/rustc/bin:/opt/qt6/bin:/usr/local/bin:/usr/bin:/bin \
      "$@"
}

echo "=== Проверка Rust ==="
as_user rustc --version
as_user cargo --version
as_user mkdir -p "$work/completed-plasma-deps"

for package in qcoro-0.13.0 corrosion-0.6.1; do
    marker="$work/completed-plasma-deps/$package"
    if [ -f "$marker" ]; then
        echo "=== Уже установлен: $package ==="
        continue
    fi

    case "$package" in
        qcoro-0.13.0)
            checksum=1cc2b522b90d8d0842523f751e75c99b
            url=https://github.com/danvratil/qcoro/archive/v0.13.0/qcoro-0.13.0.tar.gz
            options=(
                -DCMAKE_INSTALL_PREFIX=/opt/qt6
                -DUSE_QT_VERSION=6
                -DBUILD_SHARED_LIBS=ON
                -DBUILD_TESTING=OFF
                -DQCORO_BUILD_TESTING=OFF
                -DQCORO_BUILD_EXAMPLES=OFF
                -DQCORO_WITH_QTWEBSOCKETS=OFF
            )
            ;;
        corrosion-0.6.1)
            checksum=060ee79a6bf7c5a2e4e810370fbb7b61
            url=https://github.com/corrosion-rs/corrosion/archive/v0.6.1/corrosion-0.6.1.tar.gz
            options=(
                -DCMAKE_INSTALL_PREFIX=/usr
                -DCMAKE_INSTALL_LIBEXECDIR=lib
                -DCORROSION_BUILD_TESTS=OFF
            )
            ;;
    esac

    archive="$work/$package.tar.gz"
    source="$work/$package"
    build="$work/build-$package"

    echo "=== Подготовка: $package ==="

    if [ ! -f "$archive" ]; then
        as_user curl -fL --retry 3 --connect-timeout 30 \
            "$url" -o "$archive.download"
        printf '%s  %s\n' "$checksum" "$archive.download" |
            md5sum -c -
        as_user mv "$archive.download" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | md5sum -c -

    if [ ! -d "$source" ]; then
        as_user tar -xf "$archive" -C "$work"
    fi

    as_user cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_BUILD_TYPE=Release \
        "${options[@]}" \
        2>&1 | as_user tee "$work/configure-$package.log"

    as_user cmake --build "$build" --parallel 1 \
        2>&1 | as_user tee "$work/build-$package.log"

    cmake --install "$build"
    /sbin/ldconfig
    as_user touch "$marker"
    echo "=== Установлен: $package ==="
done

echo "=== Проверка ==="
find /opt/qt6/lib/cmake /usr/lib/cmake /usr/share/cmake \
    -type f \( -iname 'QCoro6Config.cmake' \
    -o -iname 'CorrosionConfig.cmake' \) 2>/dev/null

echo "=== Boost и FFmpeg ==="
if [ -r /usr/include/boost/version.hpp ]; then
    grep '^#define BOOST_LIB_VERSION ' /usr/include/boost/version.hpp
else
    echo "Заголовки Boost не найдены."
fi
as_user pkg-config --modversion libavcodec libavformat libavutil ||
    echo "Не все библиотеки FFmpeg найдены."

df -h /
