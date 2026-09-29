#!/bin/sh
# Super+N. Start quickshell if it is not running, then ask it to show or hide settings.
export PATH="$PATH:/usr/local/bin:${HOME}/.local/bin"
log_dir="${HOME}/.local/state/suse-rice"
mkdir -p "$log_dir"

if ! pgrep -x qs >/dev/null 2>&1; then
    qs >>"${log_dir}/quickshell.log" 2>&1 &
fi

i=0
while [ "$i" -lt 50 ]; do
    if qs ipc call settings toggle >/dev/null 2>&1; then
        exit 0
    fi
    i=$((i + 1))
    sleep 0.1
done
exit 1
