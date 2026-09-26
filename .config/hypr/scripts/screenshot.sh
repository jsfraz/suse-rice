#!/bin/bash
# Print Screen: region, window, or a whole output. Grim saves a PNG and copies it.
export PATH="$PATH:/usr/local/bin:${HOME}/.local/bin"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a grim "$@"
}

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        notify -u critical "Snímek obrazovky" "Chybí příkaz: $1"
        exit 1
    fi
}

pictures_dir() {
    if [ -z "${XDG_PICTURES_DIR:-}" ] && [ -f "${HOME}/.config/user-dirs.dirs" ]; then
        # shellcheck disable=SC1091
        . "${HOME}/.config/user-dirs.dirs"
    fi
    printf '%s/Screenshots\n' "${XDG_PICTURES_DIR:-${HOME}/Pictures}"
}

# Border and fill follow the matugen accent so the overlay matches the rest of the rice.
slurp_style() {
    local accent
    accent=$(sed -n 's/^[[:space:]]*accent:[[:space:]]*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' \
        "${XDG_CONFIG_HOME:-${HOME}/.config}/rofi/colors.rasi" | head -n 1)
    case "$accent" in
        '#'[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
        *) accent='#5ec8ff' ;;
    esac
    slurp_border="${accent}ee"
    slurp_fill="${accent}55"
    slurp_shade='#07101899'
}

run_slurp() {
    slurp -b "$slurp_shade" -c "$slurp_border" -s "$slurp_fill" -w 3 "$@"
}

save_shot() {
    local dir file
    dir=$(pictures_dir)
    mkdir -p "$dir"
    file="${dir}/Screenshot-$(date +%Y-%m-%d-%H%M%S).png"
    if ! grim "$@" "$file"; then
        notify -u critical "Snímek obrazovky" "Snímek se nepodařilo pořídit."
        exit 1
    fi
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy -t image/png <"$file"
    fi
    notify -i "$file" "Snímek obrazovky" "$(basename "$file")"
}

window_geometries() {
    local ids
    ids=$(hyprctl monitors -j | jq -c '[ .[] | (.activeWorkspace.id // 0), (.specialWorkspace.id // 0) ] | map(select(. != 0)) | unique')
    hyprctl clients -j | jq -r --argjson ids "$ids" '
        .[]
        | select(
            .mapped == true
            and .hidden != true
            and (.workspace.id as $id | $ids | index($id) != null)
            and .size[0] > 0
            and .size[1] > 0
          )
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
    '
}

require grim
require slurp
require jq
require rofi
require hyprctl

color=$(rcm get color 2>/dev/null || true)
[ -n "$color" ] || color=blue

choice=$(printf 'Výběr\0icon\x1fedit-select\nOkno\0icon\x1fpreferences-system-windows\nObrazovka\0icon\x1fvideo-display\n' \
    | rofi -dmenu -no-custom -show-icons \
        -icon-theme "crystal-remix-${color}" \
        -theme "${XDG_CONFIG_HOME:-${HOME}/.config}/rofi/screenshot.rasi") || exit 0

[ -n "$choice" ] || exit 0

slurp_style

case "$choice" in
    Výběr)
        geom=$(run_slurp -d) || exit 0
        [ -n "$geom" ] || exit 0
        save_shot -g "$geom"
        ;;
    Okno)
        geoms=$(window_geometries)
        if [ -z "$geoms" ]; then
            notify "Snímek obrazovky" "Žádné okno k zachycení."
            exit 1
        fi
        geom=$(printf '%s\n' "$geoms" | run_slurp -r) || exit 0
        [ -n "$geom" ] || exit 0
        save_shot -g "$geom"
        ;;
    Obrazovka)
        count=$(hyprctl monitors -j | jq 'length')
        if [ "${count:-0}" -gt 1 ]; then
            # -o offers each output; -r accepts only a whole screen. %o is its name.
            output=$(run_slurp -o -r -f '%o') || exit 0
        else
            # Let the picker finish its close animation before the frame is taken.
            sleep 0.25
            output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
            [ -n "$output" ] || output=$(hyprctl monitors -j | jq -r '.[0].name')
        fi
        [ -n "$output" ] || exit 0
        save_shot -o "$output"
        ;;
    *)
        exit 0
        ;;
esac
