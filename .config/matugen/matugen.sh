#!/bin/sh

# systemd user units (darkman) omit ~/.cargo/bin, where cargo-installed matugen lives.
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

# TODO check if anything changed since last run or just optimize the code

# colors
forced_color=$(rcm get forcedColor -b false)

if [ $forced_color = true ]; then
    # color set by force
    color=$(rcm get color -b blue)
    color_hex=$(~/.config/matugen/color_utils.py -color2hex $color)
else
    color_from_wallpaper=$(rcm get colorFromWallpaper -b false)
    if [ $color_from_wallpaper = true ]; then
        # color based on the wallpaper
        color_hex=$(~/.config/matugen/color_utils.py -hex $(rcm get wallpaper -b /usr/share/hypr/wall0.png))
        color=$(~/.config/matugen/color_utils.py -hex2color $color_hex)
    else
        # color from palette based on the wallpaper
        color_hex=$(~/.config/matugen/color_utils.py -hex $(rcm get wallpaper -b /usr/share/hypr/wall0.png))
        color=$(~/.config/matugen/color_utils.py -hex2color $color_hex)
        color_hex=$(~/.config/matugen/color_utils.py -color2hex $color)
    fi
fi

# brightness mode
forced_brightness_mode=$(rcm get forcedBrightnessMode -b false)
if [ $forced_brightness_mode = true ]; then
    # brightness mode set by force
    brightness_mode=$(rcm get brightness_mode -b light)
else
    # brightness mode based on darkman
    brightness_mode=$(darkman get)
fi

# matugen
matugen color hex $color_hex -m $brightness_mode

# TODO move to post hooks

icons=crystal-remix-$color

# GTK
# gsettings list-recursively org.gnome.desktop.interface
# gsettings set org.gnome.desktop.interface gtk-theme 'TODO'
# gsettings set org.gnome.desktop.interface color-scheme 'prefer-TODO'
gsettings set org.gnome.desktop.interface icon-theme $icons

# QT
kwriteconfig6 --file kdeglobals --group Icons --key Theme $icons