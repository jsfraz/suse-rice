#!/bin/sh
# Current Hyprland workspace number only. Not a switcher.
last=""
while true; do
    id=$(hyprctl activeworkspace 2>/dev/null | awk '/workspace ID/ {print $3; exit}')
    if [ -z "$id" ]; then
        id=1
    fi
    if [ "$id" != "$last" ]; then
        printf '{"text":"%s"}\n' "$id"
        last=$id
    fi
    sleep 0.2
done
