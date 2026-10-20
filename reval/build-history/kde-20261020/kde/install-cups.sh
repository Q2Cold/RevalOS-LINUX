#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка установки CUPS, строка $LINENO"' ERR

test "$EUID" -eq 0

work=/home/myos/reval-build/kde-deps
source="$work/cups-2.4.19"
helper=/home/myos/reval-build/kde/as-myos.py

as_user() {
    /usr/bin/python3 "$helper" "$@"
}

test -f "$helper"
pkg-config --modversion gnutls
as_user mkdir -p "$work"

getent group lp >/dev/null || groupadd --system lp
getent passwd lp >/dev/null ||
    useradd --system -g lp -d /var/spool/cups \
        -s /bin/false -c "Print Service User" lp
getent group lpadmin >/dev/null || groupadd --system lpadmin

archive="$work/cups-2.4.19-source.tar.gz"
if [ ! -f "$archive" ]; then
    as_user curl -fL --retry 3 --connect-timeout 30 \
        https://github.com/OpenPrinting/cups/releases/download/v2.4.19/cups-2.4.19-source.tar.gz \
        -o "$archive.download"
    as_user mv "$archive.download" "$archive"
fi

printf '%s  %s\n' \
    06b7a3921812988cdb3198ff74ae381d "$archive" |
    md5sum -c -

if [ ! -d "$source" ]; then
    as_user tar -xf "$archive" -C "$work"
fi

as_user /bin/bash -c '
    set -Eeuo pipefail
    cd "$1"

    if ! grep -Fq "ipp->prev->next == *attr" cups/ipp.c; then
        sed -i "/& ipp->prev)/s/prev/& \&\& ipp->prev->next == *attr/" cups/ipp.c
    fi

    ./configure \
        --prefix=/usr \
        --libdir=/usr/lib \
        --with-rundir=/run/cups \
        --with-system-groups=lpadmin \
        --with-docdir=/usr/share/cups/doc-2.4.19

    make -j1
' reval-cups "$source" 2>&1 |
    as_user tee "$work/build-cups-2.4.19.log"

make -C "$source" install
/sbin/ldconfig

echo '=== Проверка CUPS ==='
/usr/bin/cups-config --version
test -r /usr/include/cups/cups.h
test -e /usr/lib/libcups.so
echo 'Заголовки и библиотека CUPS установлены.'
df -h /
