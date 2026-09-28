#!/bin/bash
# Backlight step plus Avizo OSD.
# -e4 -n2 matches the previous Hyprland binds: exponential curve, floor at 2%
# so the panel cannot go black. lightctl cannot pass --min-value.
set -euo pipefail

case ${1:-} in
    up)   op='+' ;;
    down) op='-' ;;
    *)
        echo "usage: $0 up|down" >&2
        exit 2
        ;;
esac

out=$(brightnessctl -e4 -n2 -m set "5%${op}" | head -n 1)
light=$(printf '%s\n' "$out" | cut -d, -f4)
light=${light%\%}
light=${light%%.*}

if [ "$light" -le 33 ]; then
    image=brightness_low
elif [ "$light" -le 66 ]; then
    image=brightness_medium
else
    image=brightness_high
fi
if [ "$(~/.config/hypr/scripts/brightness-mode.sh)" = dark ]; then
    image=${image}_dark
fi

progress=$(awk -v l="$light" 'BEGIN { printf "%.2f", l / 100 }')
exec avizo-client --image-resource="$image" --progress="$progress"
