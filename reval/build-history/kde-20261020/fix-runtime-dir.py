from pathlib import Path
import shutil
import time

path = Path("/etc/profile")
text = path.read_text()
old = 'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/xdg-$USER}'
new = '''# Use the runtime directory managed by systemd-logind.
if [ -d "/run/user/$(id -u)" ] &&
   [ -O "/run/user/$(id -u)" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi'''

if text.count(old) != 1:
    raise SystemExit("Ожидаемая строка не найдена однозначно. Файл не изменён.")

backup = f"/etc/profile.backup-{time.strftime('%Y%m%d-%H%M%S')}"
shutil.copy2(path, backup)
path.write_text(text.replace(old, new))
print("Профиль исправлен. Резервная копия:", backup)
