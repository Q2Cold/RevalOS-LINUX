#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

fail() {
    echo "Ошибка: $*" >&2
    exit 1
}

[[ $# == 2 ]] ||
    fail "Использование: sudo $0 РАБОЧИЙ_КАТАЛОГ НОВЫЙ_КАТАЛОГ_РЕЗУЛЬТАТА"

[[ $EUID == 0 ]] || fail "Запусти через sudo."

repo="$(cd -- "$(dirname -- "$0")/.." && pwd)"
work="$(realpath -e -- "$1")"
output="$(realpath -m -- "$2")"
rootfs="$work/rootfs"
release=7.1.8-reval-universal

for tool in realpath findmnt python3 cpio gzip mksquashfs \
            grub-mkrescue xorriso sha256sum; do
    command -v "$tool" >/dev/null || fail "Не найден $tool"
done

[[ -d "$rootfs" ]] || fail "Не найден rootfs."
[[ -d "$work/initramfs" ]] || fail "Не найден initramfs."
[[ -s "$rootfs/boot/vmlinuz-$release" ]] || fail "Не найдено ядро."
[[ -d "$rootfs/lib/modules/$release" ]] || fail "Не найдены модули."
[[ -x "$work/initramfs/bin/busybox" ]] || fail "Не найден BusyBox."
[[ -f "$repo/reval/boot/init" ]] || fail "Не найден сценарий init."
[[ -f "$repo/reval/boot/grub.cfg" ]] || fail "Не найден grub.cfg."
[[ ! -e "$output" ]] || fail "Каталог результата уже существует."

case "$output/" in
    "$work/"*) fail "Каталог результата должен быть вне рабочего каталога." ;;
esac

# Не допускаем захват подключённых файловых систем.
mounts="$(findmnt -J -o TARGET)"
python3 -c '
import json, os, sys
roots = [os.path.realpath(p) for p in sys.argv[1:]]
def walk(items):
    for item in items:
        target = os.path.realpath(item["target"])
        if any(target == r or target.startswith(r + "/") for r in roots):
            raise SystemExit("Обнаружено монтирование: " + target)
        walk(item.get("children", []))
walk(json.load(sys.stdin)["filesystems"])
' "$rootfs" "$work/initramfs" <<< "$mounts"

sh -n "$repo/reval/boot/init"

mkdir -p -- "$output"
stage="$(mktemp -d "$output/.stage-XXXXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
trap 'echo "Сборка остановлена, строка $LINENO" >&2' ERR

mkdir -p "$stage/iso/boot/grub" "$stage/iso/live"

echo '=== Подготовка initramfs ==='
cp -a "$work/initramfs" "$stage/initramfs"
install -m755 "$repo/reval/boot/init" "$stage/initramfs/init"

(
    cd "$stage/initramfs"
    find . -xdev -print0 |
        LC_ALL=C sort -z |
        cpio --null -o --format=newc --owner=0:0 |
        gzip -n -9
) > "$stage/iso/boot/initramfs.gz"

gzip -t "$stage/iso/boot/initramfs.gz"

install -m644 "$rootfs/boot/vmlinuz-$release" \
    "$stage/iso/boot/vmlinuz"
install -m644 "$repo/reval/boot/grub.cfg" \
    "$stage/iso/boot/grub/grub.cfg"

echo '=== Упаковка подготовленного rootfs ==='
mksquashfs "$rootfs" "$stage/iso/live/filesystem.squashfs" \
    -noappend -comp zstd -Xcompression-level 15 \
    -b 1M -processors 2

echo '=== Создание ISO ==='
name=reval-os-preview-x86_64.iso
grub-mkrescue -o "$stage/$name" "$stage/iso" -- -volid REVAL_OS
test -s "$stage/$name"

mv "$stage/$name" "$output/$name"
(
    cd "$output"
    sha256sum "$name" > "$name.sha256"
    sha256sum -c "$name.sha256"
)

git -C "$repo" rev-parse HEAD > "$output/source-commit.txt"
git -C "$repo" status --porcelain > "$output/source-status.txt"

if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
    chown "$SUDO_UID:$SUDO_GID" \
        "$output" "$output/$name" "$output/$name.sha256" \
        "$output/source-commit.txt" "$output/source-status.txt"
fi

echo "=== Готово: $output/$name ==="
