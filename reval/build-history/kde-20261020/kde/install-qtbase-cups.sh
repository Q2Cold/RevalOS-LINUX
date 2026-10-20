#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка, строка $LINENO. Графический вход можно вернуть: systemctl start lightdm"' ERR

test "$EUID" -eq 0
build=/home/myos/reval-build/qt-6.11.2/build-qtbase-xcb

grep -qx 'QT_FEATURE_cups:INTERNAL=ON' "$build/CMakeCache.txt"
test -f "$build/lib/libQt6PrintSupport.so.6.11.2"

echo '=== Остановка графического сеанса ==='
systemctl stop lightdm

echo '=== Установка Qt Base ==='
cmake --install "$build"
/sbin/ldconfig

echo '=== Проверка поддержки CUPS ==='
grep -E '^#define QT_FEATURE_cups 1$' \
    /opt/qt6/include/QtPrintSupport/qtprintsupport-config.h

test -r \
    /opt/qt6/include/QtPrintSupport/6.11.2/QtPrintSupport/private/qcups_p.h

echo '=== Возвращение экрана входа ==='
systemctl start lightdm

echo '=== Продолжение сборки портала KDE ==='
bash /home/myos/reval-build/kde/run-plasma.sh seventh-group.md5

echo '=== Qt обновлён, группа портала KDE установлена ==='
df -h /
