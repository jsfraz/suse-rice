#!/bin/sh
# Wi-Fi strength, ethernet link speed, or no connection. Tooltip matches the AGS bar.
icon="󰤪"
tooltip="No connection"
class="disconnected"

iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
if [ -n "$iface" ]; then
    kind=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: -v d="$iface" '$1==d {print $2; exit}')
    case "$kind" in
        wifi)
            class="wifi"
            signal=$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null | awk -F: '$1=="*" {print $2; exit}')
            case "$signal" in
                ""|*[!0-9]*) signal=0 ;;
            esac
            tooltip="${signal}%"
            if [ "$signal" -ge 80 ]; then icon="󰤨"
            elif [ "$signal" -ge 60 ]; then icon="󰤥"
            elif [ "$signal" -ge 40 ]; then icon="󰤢"
            elif [ "$signal" -ge 20 ]; then icon="󰤟"
            else icon="󰤫"
            fi
            ;;
        ethernet)
            class="ethernet"
            icon="󰈀"
            speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || echo -1)
            case "$speed" in
                ""|*[!0-9-]*) speed=-1 ;;
            esac
            if [ "$speed" -gt 0 ]; then
                tooltip="${speed} Mb/s"
            else
                tooltip="? Mb/s"
            fi
            ;;
    esac
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tooltip" "$class"
