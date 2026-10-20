#!/bin/bash
set -Eeuo pipefail
test "$EUID" -eq 0

backup="/root/reval-branding-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -a /etc/os-release "$backup/os-release"
cp -L /etc/os-release "$backup/os-release.contents"

temporary="$(mktemp /etc/os-release.reval.XXXXXX)"
cat > "$temporary" <<'RELEASE'
NAME="Reval OS"
PRETTY_NAME="Reval OS 0.3 Development"
ID=reval
VERSION="0.3 Development"
VERSION_ID="0.3"
HOME_URL="https://github.com/Q2Cold/RevalOS-LINUX"
RELEASE_TYPE="development"
RELEASE
chmod 644 "$temporary"
mv -f "$temporary" /etc/os-release

echo "Резервная копия: $backup"
cat /etc/os-release
