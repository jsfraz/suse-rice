#!/bin/bash
# Push the rcm keyboard layout into Hyprland. --restart-wayvnc also respawns wayvnc,
# which only reads -k when it starts.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

layout=$(rcm get keyboard -f cz)
variant=$(rcm get keyboardVariant -f -)
layout=${layout//$'\n'/}
variant=${variant//$'\n'/}
if [ "$variant" = "-" ]; then
    variant=""
fi

# This Hyprland build rejects `hyprctl keyword` (non-legacy parser). Push the layout through Lua.
hyprctl eval "hl.config({ input = { kb_layout = \"$layout\", kb_variant = \"$variant\" } })"

if [ "${1:-}" = "--restart-wayvnc" ]; then
    pkill -x wayvnc || true
    sleep 0.2
    wayvnc 0.0.0.0 -f 60 -k "$layout" -r >/dev/null 2>&1 &
fi
