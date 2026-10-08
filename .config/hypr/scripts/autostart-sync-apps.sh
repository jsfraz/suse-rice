#!/bin/sh
set -eu
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

if command -v kdeconnectd >/dev/null 2>&1; then
    if ! pgrep -f '[k]deconnectd' >/dev/null 2>&1; then
        kdeconnectd >/dev/null 2>&1 &
    fi
    if command -v kdeconnect-indicator >/dev/null 2>&1 && ! pgrep -f '[k]deconnect-indicator' >/dev/null 2>&1; then
        kdeconnect-indicator >/dev/null 2>&1 &
    fi
fi

"${HOME}/.config/hypr/scripts/megasync-tray.sh" &

