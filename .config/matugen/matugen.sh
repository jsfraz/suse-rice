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

# Win7Bulid cursors follow the same brightness mode as the theme above.
# Size matches XCURSOR_SIZE in hyprland.lua.
if [ "$brightness_mode" = dark ]; then
    cursor_theme=Win7Bulid-cursors-dark
else
    cursor_theme=Win7Bulid-cursors
fi
cursor_size=24

gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$cursor_theme"
kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize "$cursor_size"

# darkman.service does not sit inside the compositor, so pull the session vars uwsm exported.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hypr_env=$(systemctl --user show-environment 2>/dev/null || true)
    hypr_var=$(printf '%s\n' "$hypr_env" | grep '^WAYLAND_DISPLAY=' || true)
    [ -n "$hypr_var" ] && export "$hypr_var"
    hypr_var=$(printf '%s\n' "$hypr_env" | grep '^HYPRLAND_INSTANCE_SIGNATURE=' || true)
    [ -n "$hypr_var" ] && export "$hypr_var"
    hypr_var=$(printf '%s\n' "$hypr_env" | grep '^XDG_RUNTIME_DIR=' || true)
    [ -n "$hypr_var" ] && export "$hypr_var"
    unset hypr_env hypr_var
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl setcursor "$cursor_theme" "$cursor_size"
    # Third argument exports the variable over dbus, so later apps inherit it.
    hyprctl eval "hl.env(\"XCURSOR_THEME\", \"$cursor_theme\", true)"
fi