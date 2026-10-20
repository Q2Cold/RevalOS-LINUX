#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка: ${package:-подготовка}, строка $LINENO"' ERR

[ "$EUID" -eq 0 ] || {
    echo "Запусти через su -c."
    exit 1
}

work=/home/myos/reval-build/kde-deps

as_user() {
    /usr/bin/python3 /home/myos/reval-build/kde/as-myos.py "$@"
}

for package in libsass-3.6.6 sassc-3.6.2; do
    case "$package" in
        libsass-3.6.6)
            if pkg-config --exists libsass; then
                echo "=== libsass уже установлен ==="
                continue
            fi
            checksum=afda97284d75a030cabadf5b9f998a3b
            url=https://github.com/sass/libsass/archive/3.6.6/libsass-3.6.6.tar.gz
            ;;
        sassc-3.6.2)
            if [ -x /usr/bin/sassc ]; then
                echo "=== sassc уже установлен ==="
                continue
            fi
            checksum=4c3b06ce2979f2a9f0a35093e501d8bb
            url=https://github.com/sass/sassc/archive/3.6.2/sassc-3.6.2.tar.gz
            ;;
    esac

    archive="$work/$package.tar.gz"
    source="$work/$package"

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

    options=(--prefix=/usr)
    if [[ "$package" == libsass-* ]]; then
        options+=(--disable-static)
    fi

    as_user /bin/bash -c '
        set -e
        cd "$1"
        shift
        autoreconf -fi
        ./configure "$@"
    ' reval-build "$source" "${options[@]}"

    as_user make -C "$source" -j 1
    make -C "$source" install
    /sbin/ldconfig

    echo "=== Установлен: $package ==="
done

echo "=== Проверка sassc ==="
/usr/bin/sassc --version
df -h /
