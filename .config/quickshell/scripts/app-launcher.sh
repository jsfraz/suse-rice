#!/bin/sh
# Super+R / waybar OS button. Dismiss settings first so the two overlays never stack.
export PATH="$PATH:/usr/local/bin:${HOME}/.local/bin"
qs ipc call settings hide >/dev/null 2>&1 || true
exec rofi -show combi -combi-modes 'drun,ssh' -modes combi \
    -theme "${HOME}/.config/rofi/launcher.rasi" \
    -show-icons \
    -icon-theme "crystal-remix-$(rcm get color)"
