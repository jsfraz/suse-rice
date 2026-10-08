#!/bin/sh
# One-time setup: unlock gnome-keyring on Hyprland autologin (no GDM → PAM never starts keyring).
set -e
dir="${HOME}/.config/suse-rice"
file="${dir}/unlock-keyring"
mkdir -p "$dir"
if [ -f "$file" ]; then
    echo "Already exists: $file"
    exit 0
fi
echo "Enter the password for your login keyring (often the same as your Linux login password)."
echo "It will be stored only in ${file} (mode 600) for session unlock."
printf "Keyring password: "
stty -echo
IFS= read -r pass
stty echo
printf "\n"
printf '%s' "$pass" >"$file"
chmod 600 "$file"
unset pass
echo "Saved. Restart Hyprland or run ~/.config/hypr/scripts/session-services.sh"
