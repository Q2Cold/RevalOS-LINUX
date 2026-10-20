#!/bin/bash
set -Eeuo pipefail
test "$EUID" -eq 0
test -x /usr/bin/startplasma-x11

install -d /usr/local/bin /usr/share/xsessions

cat > /usr/local/bin/reval-plasma-session <<'SESSION'
#!/bin/sh

export PATH="/opt/qt6/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.nix-profile/bin"
export QT_PLUGIN_PATH="/usr/lib/plugins:/opt/qt6/plugins"
export QML_IMPORT_PATH="/usr/lib/qml:/opt/qt6/qml"
export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
export XDG_DATA_DIRS="/usr/local/share:/usr/share:/opt/qt6/share:$HOME/.nix-profile/share"
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export XDG_SESSION_TYPE=x11

unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/reval"
mkdir -p "$state_dir" || exit 1
exec /usr/bin/startplasma-x11 >"$state_dir/plasma-session.log" 2>&1
SESSION

chmod 755 /usr/local/bin/reval-plasma-session
sh -n /usr/local/bin/reval-plasma-session

cat > /usr/share/xsessions/reval-plasma.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Reval Plasma (X11)
Comment=Reval desktop with KDE Plasma
Exec=/usr/local/bin/reval-plasma-session
TryExec=/usr/bin/startplasma-x11
DesktopNames=KDE;
DESKTOP

chmod 644 /usr/share/xsessions/reval-plasma.desktop
echo '=== Сеанс Reval Plasma добавлен ==='
