#!/bin/sh
# KDE Connect, MEGA, and LocalSend tray apps. Called from hyprland autostart via uwsm.
set -eu
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

wait_for_wayland() {
    i=0
    while [ "$i" -lt 80 ]; do
        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ] 2>/dev/null; then
            return 0
        fi
        i=$((i + 1))
        sleep 0.1
    done
    return 0
}

if command -v kdeconnectd >/dev/null 2>&1; then
    if ! pgrep -f '[k]deconnectd' >/dev/null 2>&1; then
        kdeconnectd &
    fi
    if command -v kdeconnect-indicator >/dev/null 2>&1 && ! pgrep -f '[k]deconnect-indicator' >/dev/null 2>&1; then
        kdeconnect-indicator &
    fi
fi

if command -v megasync >/dev/null 2>&1 && ! pgrep -x megasync >/dev/null 2>&1; then
    megasync &
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info org.localsend.localsend_app >/dev/null 2>&1; then
    if ! pgrep -x localsend >/dev/null 2>&1; then
        wait_for_wayland
        flatpak run org.localsend.localsend_app &
    fi
fi
