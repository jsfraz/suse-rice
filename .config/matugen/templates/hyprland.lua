return {
    image = "{{image}}",
<* for name, value in colors *>
    {{name}} = "0xff{{value.default.hex_stripped}}",
<* endfor *>

    -- Borders / shadow: same vivid, mode-aware approach as kitty
<* if {{ is_dark_mode }} *>
    active_border = "rgba({{ colors.primary.default.hex | set_saturation: 80.0 | set_lightness: 55.0 | replace: "#", "" }}ee)",
    active_border_alt = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 48.0 | replace: "#", "" }}ee)",
    inactive_border = "rgba({{ colors.outline.default.hex_stripped }}aa)",
    window_shadow = 0xee1a1a1a,
<* else *>
    active_border = "rgba({{ colors.primary.default.hex | set_saturation: 80.0 | set_lightness: 42.0 | replace: "#", "" }}ff)",
    active_border_alt = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 38.0 | replace: "#", "" }}ff)",
    inactive_border = "rgba({{ colors.outline.default.hex_stripped }}cc)",
    window_shadow = 0x33000000,
<* endif *>
}
