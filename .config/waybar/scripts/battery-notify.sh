#!/bin/sh
# Low-battery and fully-charged alerts. Same thresholds as the AGS bar.
low_warned=0
full_notified=0
seen=0

while true; do
    found=0
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue
        found=1
        cap=$(cat "$bat/capacity" 2>/dev/null || echo "")
        status=$(cat "$bat/status" 2>/dev/null || echo "")
        case "$cap" in
            ''|*[!0-9]*) cap="" ;;
        esac
        if [ -z "$cap" ]; then
            break
        fi

        case "$status" in
            Charging|Full) plugged=1 ;;
            *) plugged=0 ;;
        esac

        # Already full at startup is not a new event.
        if [ "$seen" -eq 0 ]; then
            seen=1
            if [ "$cap" -eq 100 ] && [ "$plugged" -eq 1 ]; then
                full_notified=1
            fi
        fi

        if [ "$cap" -le 15 ] && [ "$plugged" -eq 0 ] && [ "$low_warned" -eq 0 ]; then
            notify-send -u critical -i battery-low "Low Battery" "Battery level is at ${cap}%"
            low_warned=1
        fi
        if [ "$cap" -gt 20 ]; then
            low_warned=0
        fi

        if [ "$cap" -eq 100 ] && [ "$plugged" -eq 1 ] && [ "$full_notified" -eq 0 ]; then
            notify-send -u normal -i battery-full-charged "Battery Fully Charged" "Battery is at 100%"
            full_notified=1
        fi
        if [ "$cap" -lt 100 ] || [ "$plugged" -eq 0 ]; then
            full_notified=0
        fi
        break
    done

    if [ "$found" -eq 0 ]; then
        sleep 30
    else
        sleep 10
    fi
done
