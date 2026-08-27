#!/bin/bash
# Derive hyprlang colors.conf from the Lua palette and install both for greetd.
set -euo pipefail

lua="${HOME}/.config/hypr/colors.lua"
conf="${HOME}/.config/hyprlogin/colors.conf"

{
	echo "# Generated from ${lua} — sourced by hyprlogin.conf"
	sed -n 's/^[[:space:]]*\([a-z_]*\) = "\(rgba([^"]*)\)".*/$\1 = \2/p' "${lua}"
} > "${conf}"

ok=0
sudo install -Dm644 "${lua}" /etc/hyprlogin/colors.lua || ok=1
sudo install -Dm644 "${conf}" /etc/hyprlogin/colors.conf || ok=1
if [ "${ok}" -ne 0 ]; then
	echo "warning: could not install palette to /etc/hyprlogin (need sudo)" >&2
fi
