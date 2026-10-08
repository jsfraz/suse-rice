#!/bin/sh
set -e
src="${HOME}/.config/hypr/polkit/49-networkmanager.rules"
dest="/etc/polkit-1/rules.d/49-networkmanager.rules"
if [ ! -f "$src" ]; then
    echo "Missing $src (is hypr config linked?)" >&2
    exit 1
fi
sudo install -D -m 644 "$src" "$dest"
echo "Installed $dest — polkit picks it up immediately."
