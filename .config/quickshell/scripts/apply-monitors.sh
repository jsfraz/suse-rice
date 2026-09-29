#!/bin/bash
# Apply the monitor lines stored in rcm. "-" or an empty value keeps hyprland.lua's default.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

raw=$(rcm get monitors -f - || true)
raw=${raw%$'\n'}
if [ -z "$raw" ] || [ "$raw" = "-" ]; then
    exit 0
fi

while IFS= read -r line; do
    [ -n "$line" ] || continue
    IFS='|' read -r name mode x y scale transform enabled <<EOF
$line
EOF
    if [ "$enabled" = "0" ]; then
        hyprctl eval "hl.monitor({ output = \"$name\", disabled = true })"
    else
        hyprctl eval "hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"${x}x${y}\", scale = $scale, transform = $transform, disabled = false })"
    fi
done <<EOF
$raw
EOF
