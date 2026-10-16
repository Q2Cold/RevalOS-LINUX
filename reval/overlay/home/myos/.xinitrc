#!/bin/sh
. "$HOME/.config/myos/nix-session.sh"
# MYOS: user session bus
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd         DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR DISPLAY XAUTHORITY
fi

if [ -f "$HOME/.Xresources" ]; then
    xrdb -merge "$HOME/.Xresources"
fi
xterm &
exec openbox-session
