#!/bin/bash
# Lock on the current wallpaper. hypridle calls this when idle and before sleep.
# Extra arguments are passed to hyprlock (before sleep: --no-fade-in).
export PATH="$PATH:/usr/local/bin:${HOME}/.local/bin"

set -u

wallpaper=$(rcm get wallpaper)
wallpaper="${wallpaper/#\~/$HOME}"

cache="${HOME}/.cache/suse-rice"
mkdir -p "$cache"

# hyprlock.conf points at this file. WebP is not decoded by the installed
# hyprgraphics build, so every wallpaper is flattened to one PNG.
lock_image="${cache}/hyprlock-wallpaper.png"
if ! python3 -c 'from PIL import Image; import sys; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2], "PNG")' "$wallpaper" "$lock_image"; then
    command -v notify-send >/dev/null 2>&1 && notify-send -a hyprlock "Lock screen" "Could not read the wallpaper"
    exit 1
fi

hyprsaver --quit >/dev/null 2>&1 || true

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

if ! command -v hyprlock >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 && notify-send -a hyprlock "Lock screen" "Missing command: hyprlock"
    exit 1
fi

# matugen writes the palette. Wait the same way waybar waits for colors.css.
colors="${HOME}/.config/hypr/hyprlock-colors.conf"
i=0
while [ ! -f "$colors" ] && [ "$i" -lt 50 ]; do
    i=$((i + 1))
    sleep 0.1
done

exec hyprlock "$@"
