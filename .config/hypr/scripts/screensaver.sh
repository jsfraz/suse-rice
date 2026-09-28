#!/bin/bash
# hypridle starts this after 10 minutes.
# Shader comes from rcm: none, cycle, random, or a name from `hyprsaver --list-shaders`.
# Palette is the rice accent, resolved the same way as matugen.sh, plus the
# hue-shifted lighter stop think-sway feeds to lavat.
export PATH="${HOME}/.cargo/bin:/usr/local/bin:${HOME}/.local/bin:${PATH}"

color_utils="${HOME}/.config/matugen/color_utils.py"
base_config="${HOME}/.config/hypr/hyprsaver.toml"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a hyprsaver "Screensaver" "$1"
}

if ! command -v hyprsaver >/dev/null 2>&1; then
    notify "Missing command: hyprsaver"
    exit 1
fi

saver=$(rcm get screensaver -f cycle) || {
    notify "rcm get screensaver failed"
    exit 1
}

case "$saver" in
    none)
        exit 0
        ;;
    cycle|random)
        ;;
    *)
        if ! hyprsaver --list-shaders | awk 'NF && $1 != "Built-in" && $1 != "User" && $1 != "(none" { print $1 }' | grep -qxF "$saver"; then
            notify "Unknown shader: $saver"
            exit 1
        fi
        ;;
esac

# Same accent as the rest of the rice. See matugen.sh.
forced_color=$(rcm get forcedColor)
if [ "$forced_color" = true ]; then
    color=$(rcm get color)
    color_hex=$(python3 "$color_utils" -color2hex "$color")
else
    wallpaper=$(rcm get wallpaper)
    wallpaper="${wallpaper/#\~/$HOME}"
    color_from_wallpaper=$(rcm get colorFromWallpaper)
    if [ "$color_from_wallpaper" = true ]; then
        color_hex=$(python3 "$color_utils" -hex "$wallpaper")
    else
        color_hex=$(python3 "$color_utils" -hex "$wallpaper")
        color=$(python3 "$color_utils" -hex2color "$color_hex")
        color_hex=$(python3 "$color_utils" -color2hex "$color")
    fi
fi

lighter_hex=$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import color_utils; print(color_utils.lighten_hex_color(sys.argv[2]))' \
    "${HOME}/.config/matugen" "$color_hex") || {
    notify "Could not compute the screensaver color"
    exit 1
}

hex_ok() {
    case "$1" in
        \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
        *) return 1 ;;
    esac
}

if ! hex_ok "$color_hex" || ! hex_ok "$lighter_hex"; then
    notify "Invalid screensaver color: ${color_hex}"
    exit 1
fi

cache="${HOME}/.cache/suse-rice"
mkdir -p "$cache"
cfg="${cache}/hyprsaver.toml"
cp "$base_config" "$cfg"
cat >> "$cfg" <<EOF

[[palette]]
name = "rice"
type = "gradient"
stops = [
  { position = 0.0, color = "${color_hex}" },
  { position = 1.0, color = "${lighter_hex}" },
]
EOF

exec hyprsaver --config "$cfg" --shader "$saver" --palette rice
