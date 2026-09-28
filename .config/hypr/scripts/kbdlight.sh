#!/bin/bash
# ThinkPad T14 Gen 1 keyboard backlight (tpacpi::kbd_backlight).
# Fn+Space is XF86KbdLightOnOff. The EC does not change the LED; userspace
# cycles off → low → high. brightnessctl refuses 0 unless --min-value is 0.
set -euo pipefail

dev='tpacpi::kbd_backlight'

cur=$(brightnessctl -d "$dev" -c leds g)
max=$(brightnessctl -d "$dev" -c leds m)

state_dir="${XDG_RUNTIME_DIR:-/tmp}/suse-rice"
state="${state_dir}/kbdlight-level"
show_osd=1

case ${1:-} in
    cycle)
        if [ "$cur" -ge "$max" ]; then
            next=0
        else
            next=$((cur + 1))
        fi
        ;;
    up)
        if [ "$cur" -ge "$max" ]; then
            next=$max
        else
            next=$((cur + 1))
        fi
        ;;
    down)
        if [ "$cur" -le 0 ]; then
            next=0
        else
            next=$((cur - 1))
        fi
        ;;
    off)
        # A second off (idle, then sleep) must not replace a saved level with 0.
        if [ "$cur" -gt 0 ]; then
            mkdir -p "$state_dir"
            printf '%s\n' "$cur" >"$state"
        fi
        next=0
        show_osd=0
        ;;
    restore)
        if [ ! -f "$state" ]; then
            exit 0
        fi
        next=$(<"$state")
        case $next in
            ''|*[!0-9]*) exit 1 ;;
        esac
        show_osd=0
        ;;
    *)
        echo "usage: $0 cycle|up|down|off|restore" >&2
        exit 2
        ;;
esac

brightnessctl -d "$dev" -c leds -n0 set "$next" >/dev/null
if [ "${1:-}" = restore ]; then
    rm -f "$state"
fi

if [ "$show_osd" -eq 0 ]; then
    exit 0
fi

if [ "$next" -le 0 ]; then
    image=brightness_low
elif [ "$next" -lt "$max" ]; then
    image=brightness_medium
else
    image=brightness_high
fi
if [ "$(~/.config/hypr/scripts/brightness-mode.sh)" = dark ]; then
    image=${image}_dark
fi

progress=$(awk -v c="$next" -v m="$max" 'BEGIN { if (m+0 == 0) m = 1; printf "%.2f", c / m }')
exec avizo-client --image-resource="$image" --progress="$progress"
