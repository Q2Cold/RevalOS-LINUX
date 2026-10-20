#!/bin/bash
set -Eeuo pipefail
test "$EUID" -eq 0
test -s /boot/vmlinuz-7.1.8-reval-universal-fuse

python3 <<'PY'
from pathlib import Path
from datetime import datetime
import shutil

path = Path("/boot/grub/grub.cfg")
text = path.read_text()
kernel = "/boot/vmlinuz-7.1.8-reval-universal-fuse"

if kernel in text:
    print("Пункт нового ядра уже есть.")
else:
    position = text.find("menuentry ")
    if position < 0:
        raise SystemExit("Не найдено меню GRUB. Файл не изменён.")

    backup = path.with_name(
        "grub.cfg.backup-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    )
    shutil.copy2(path, backup)

    entry = '''menuentry "Reval - Linux 7.1.8 with FUSE" {
    linux /boot/vmlinuz-7.1.8-reval-universal-fuse root=PARTUUID=7eb5ecfc-2ced-41f3-94cd-34d62f97a312 ro
}

'''
    path.write_text(text[:position] + entry + text[position:])
    print("Новый пункт добавлен первым.")
    print("Резервная копия:", backup)
PY

if command -v grub-script-check >/dev/null 2>&1; then
    grub-script-check /boot/grub/grub.cfg
fi
sync
