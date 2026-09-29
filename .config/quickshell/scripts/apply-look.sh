#!/bin/bash
# Apply the wallpaper and regenerate theme colors from the current rcm values.
set -euo pipefail
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH}"

wallpaper=$(rcm get wallpaper)
wallpaper="${wallpaper#"${wallpaper%%[![:space:]]*}"}"
wallpaper="${wallpaper%"${wallpaper##*[![:space:]]}"}"
wallpaper="${wallpaper/#\~/$HOME}"

if ! pgrep -x hyprpaper >/dev/null 2>&1; then
    hyprpaper >/dev/null 2>&1 &
fi

if [ -n "$wallpaper" ]; then
    i=0
    while [ "$i" -lt 30 ]; do
        if hyprctl hyprpaper wallpaper ",$wallpaper"; then
            break
        fi
        i=$((i + 1))
        sleep 0.1
    done
fi

exec "${HOME}/.config/matugen/matugen.sh"
