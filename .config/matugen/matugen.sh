#!/bin/sh

# systemd user units (darkman) omit ~/.cargo/bin, where cargo-installed matugen lives.
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

# TODO check if anything changed since last run or just optimize the code

rice_color="${HOME}/.config/matugen/resolve-rice-color.sh"
color=$("$rice_color")
color_hex=$("$rice_color" --hex)

# Crystal Remix and rofi read `rcm get color`; keep it in sync here so launchers
# never re-scan the wallpaper (resolve-rice-color.sh is slow on every Super+R).
rcm set color "$color"

# brightness mode
forced_brightness_mode=$(rcm get forcedBrightnessMode)
if [ $forced_brightness_mode = true ]; then
    # brightness mode set by force
    brightness_mode=$(rcm get brightnessMode)
else
    # brightness mode based on darkman
    brightness_mode=$(darkman get)
fi

# matugen
matugen color hex $color_hex -m $brightness_mode

# TODO move to post hooks

icons=crystal-remix-$color

rice_cache="${HOME}/.cache/suse-rice"
mkdir -p "$rice_cache"
printf '%s\n' "$icons" > "${rice_cache}/icon-theme"

# GTK
# gsettings list-recursively org.gnome.desktop.interface
# gsettings set org.gnome.desktop.interface gtk-theme 'TODO'
# gsettings set org.gnome.desktop.interface color-scheme 'prefer-TODO'
gsettings set org.gnome.desktop.interface icon-theme $icons

# QT
kwriteconfig6 --file kdeglobals --group Icons --key Theme $icons