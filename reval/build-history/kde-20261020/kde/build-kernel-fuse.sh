#!/bin/bash
set -Eeuo pipefail
trap 'echo "Ошибка сборки ядра, строка $LINENO"' ERR
test "$EUID" -eq 0

cd /sources/linux-7.1.8
test -f .config

backup="/root/kernel-before-fuse-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -p .config "$backup/config"
cp -p /boot/grub/grub.cfg "$backup/grub.cfg"

./scripts/config --set-str LOCALVERSION "-reval-universal-fuse"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --module FUSE_FS

make olddefconfig
make prepare

release="$(make -s kernelrelease)"
test "$release" = "7.1.8-reval-universal-fuse"
grep -qx 'CONFIG_FUSE_FS=m' .config

echo "=== Сборка $release ==="
make -j1 2>&1 | tee "$backup/build.log"

make modules_install
depmod "$release"

install -m644 arch/x86/boot/bzImage "/boot/vmlinuz-$release"
install -m644 System.map "/boot/System.map-$release"
install -m644 .config "/boot/config-$release"

echo '=== Проверка модуля FUSE ==='
modinfo -k "$release" fuse

echo '=== Новое ядро установлено ==='
ls -lh "/boot/vmlinuz-$release"
echo "Резервная копия: $backup"

echo '=== Текущая конфигурация GRUB ==='
cat /boot/grub/grub.cfg
