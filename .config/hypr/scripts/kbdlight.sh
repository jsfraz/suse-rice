#!/bin/bash
# ThinkPad T14 Gen 1 keyboard backlight (tpacpi::kbd_backlight).
# Fn+Space is XF86KbdLightOnOff. The EC does not change the LED; userspace
# cycles off → low → high. brightnessctl refuses 0 unless --min-value is 0.
#
# Idle off and resume are separate hypridle processes. Resume can finish
# before a late off runs, and hypridle will not resume again until the next
# idle. A fresh resume stamp makes that late off leave the light alone.
set -euo pipefail

dev='tpacpi::kbd_backlight'

cur=$(brightnessctl -d "$dev" -c leds g)
max=$(brightnessctl -d "$dev" -c leds m)

state_dir="${HOME}/.local/state/suse-rice"
preferred="${state_dir}/kbdlight-preferred"
blanked="${state_dir}/kbdlight-blanked"
resumed="${state_dir}/kbdlight-resumed"
mkdir -p "$state_dir"
exec 9>"${state_dir}/kbdlight.lock"
flock 9

show_osd=1
cmd=${1:-}

now_ns() { date +%s%N; }

remember() {
    if [ "$1" -gt 0 ]; then
        printf '%s\n' "$1" >"$preferred"
        rm -f "$blanked"
    else
        # Manual off stays off. Idle restore must not bring it back.
        rm -f "$preferred" "$blanked"
    fi
}

case $cmd in
    cycle)
        if [ "$cur" -ge "$max" ]; then
            next=0
        else
            next=$((cur + 1))
        fi
        remember "$next"
        ;;
    up)
        if [ "$cur" -ge "$max" ]; then
            next=$max
        else
            next=$((cur + 1))
        fi
        remember "$next"
        ;;
    down)
        if [ "$cur" -le 0 ]; then
            next=0
        else
            next=$((cur - 1))
        fi
        remember "$next"
        ;;
    off)
        now=$(now_ns)
        if [ -s "$resumed" ]; then
            resume=$(<"$resumed")
            if [ $((now - resume)) -lt 3000000000 ]; then
                exit 0
            fi
        fi
        # A second off (idle, then sleep) must not replace a saved level with 0.
        if [ "$cur" -gt 0 ]; then
            printf '%s\n' "$cur" >"$preferred"
        fi
        if [ -s "$preferred" ]; then
            printf '%s\n' "$now" >"$blanked"
        fi
        next=0
        show_osd=0
        ;;
    restore)
        printf '%s\n' "$(now_ns)" >"$resumed"
        if [ ! -s "$blanked" ] || [ ! -s "$preferred" ]; then
            exit 0
        fi
        next=$(<"$preferred")
        case $next in
            ''|*[!0-9]*) exit 1 ;;
        esac
        rm -f "$blanked"
        show_osd=0
        ;;
    *)
        echo "usage: $0 cycle|up|down|off|restore" >&2
        exit 2
        ;;
esac

brightnessctl -d "$dev" -c leds -n0 set "$next" >/dev/null

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
