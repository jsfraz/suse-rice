#!/bin/sh
# Start MEGAsync in the tray after Waybar's StatusNotifier host is up.
set -eu
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

wait_for_tray_host() {
    i=0
    while [ "$i" -lt 150 ]; do
        if pgrep -x waybar >/dev/null 2>&1 \
            && busctl --user list 2>/dev/null | grep -qF 'org.kde.StatusNotifierWatcher'; then
            # Waybar registers the watcher slightly after the process starts.
            sleep 0.5
            return 0
        fi
        i=$((i + 1))
        sleep 0.2
    done
    return 1
}

command -v megasync >/dev/null 2>&1 || exit 0
pgrep -x megasync >/dev/null 2>&1 && exit 0

wait_for_tray_host || true
START_MEGASYNC_IN_BACKGROUND=1 exec megasync >/dev/null 2>&1
