#!/bin/sh
# Crystal Remix theme name for qs. Matugen writes ~/.cache/suse-rice/icon-theme.
export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

theme_file="${HOME}/.cache/suse-rice/icon-theme"
if [ -f "$theme_file" ]; then
    QS_ICON_THEME=$(tr -d ' \n\r' < "$theme_file")
else
    QS_ICON_THEME="crystal-remix-$(rcm get color 2>/dev/null || echo blue)"
    mkdir -p "$(dirname "$theme_file")"
    printf '%s\n' "$QS_ICON_THEME" > "$theme_file"
fi
export QS_ICON_THEME
