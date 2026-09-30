#!/bin/bash
# Start or stop hyprsunset from rcm. Darkman mode wins unless sunsetFollowDarkman is false.
# A running filter only gets a new temperature. A stopped one is launched and this script returns.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

# darkman.service does not sit inside the compositor, so pull the session vars uwsm exported.
if [ -z "${WAYLAND_DISPLAY:-}" ] || [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    while IFS= read -r line; do
        case "$line" in
            WAYLAND_DISPLAY=*|HYPRLAND_INSTANCE_SIGNATURE=*|XDG_RUNTIME_DIR=*)
                export "$line"
                ;;
        esac
    done < <(systemctl --user show-environment 2>/dev/null || true)
fi

follow=$(rcm get sunsetFollowDarkman -f true)
follow=${follow//$'\n'/}
enabled=$(rcm get sunsetOn -f false)
enabled=${enabled//$'\n'/}
temp=$(rcm get sunsetTemperature -f 4000)
temp=${temp//$'\n'/}

case "$temp" in
    ''|*[!0-9]*) temp=4000 ;;
esac
if [ "$temp" -lt 1000 ] || [ "$temp" -gt 20000 ]; then
    temp=4000
fi

want=0
if [ "$follow" = true ]; then
    state=$(darkman get 2>/dev/null || printf '%s\n' light)
    state=${state//$'\n'/}
    if [ "$state" = dark ]; then
        want=1
    fi
elif [ "$enabled" = true ]; then
    want=1
fi

if [ "$want" -eq 0 ]; then
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        pkill -x hyprsunset || true
    fi
    exit 0
fi

if pgrep -x hyprsunset >/dev/null 2>&1; then
    i=0
    while [ "$i" -lt 20 ]; do
        if hyprctl hyprsunset temperature "$temp"; then
            exit 0
        fi
        i=$((i + 1))
        sleep 0.1
    done
    echo "hyprsunset did not accept the temperature" >&2
    exit 1
fi

uwsm app -t service -S both -d "Blue light filter" -- hyprsunset --temperature "$temp"
i=0
while [ "$i" -lt 30 ]; do
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        exit 0
    fi
    i=$((i + 1))
    sleep 0.1
done
echo "hyprsunset did not start" >&2
exit 1
