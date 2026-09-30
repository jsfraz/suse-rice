#!/bin/sh
# Crystal Remix palette name and matugen seed hex — same rules as matugen.sh.
# Only for theme apply (matugen.sh). Rofi uses `rcm get color`, updated there.
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

color_utils="${HOME}/.config/matugen/color_utils.py"

mode=name
if [ "${1:-}" = "--hex" ]; then
    mode=hex
fi

forced_color=$(rcm get forcedColor)
if [ "$forced_color" = true ]; then
    color=$(rcm get color)
    color_hex=$(python3 "$color_utils" -color2hex "$color")
else
    wallpaper=$(rcm get wallpaper)
    wallpaper="${wallpaper/#\~/$HOME}"
    color_from_wallpaper=$(rcm get colorFromWallpaper)
    color_hex=$(python3 "$color_utils" -hex "$wallpaper")
    if [ "$color_from_wallpaper" = true ]; then
        color=$(python3 "$color_utils" -hex2color "$color_hex")
    else
        color=$(python3 "$color_utils" -hex2color "$color_hex")
        color_hex=$(python3 "$color_utils" -color2hex "$color")
    fi
fi

if [ "$mode" = hex ]; then
    printf '%s\n' "$color_hex"
else
    printf '%s\n' "$color"
fi
