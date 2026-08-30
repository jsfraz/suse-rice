return {
<* if {{ is_dark_mode }} *>
    active_border = "rgba({{ colors.primary.default.hex | set_saturation: 80.0 | set_lightness: 55.0 | replace: "#", "" }}ee)",
    active_border_alt = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 48.0 | replace: "#", "" }}ee)",
    inactive_border = "rgba({{ colors.outline.default.hex_stripped }}aa)",
    window_shadow = "rgba({{ colors.source_color.default.hex | set_lightness: 8.0 | set_saturation: 28.0 | replace: "#", "" }}ee)",
    input_inner = "rgba({{ colors.primary.default.hex | set_saturation: 32.0 | set_lightness: 30.0 | replace: "#", "" }}73)",
    check_color = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 48.0 | replace: "#", "" }}ee)",
    check_color_alt = "rgba({{ colors.primary.default.hex | set_hue: 48.0 | set_saturation: 90.0 | set_lightness: 54.0 | replace: "#", "" }}ee)",
    fail_color = "rgba({{ colors.primary.default.hex | set_hue: 8.0 | set_saturation: 88.0 | set_lightness: 52.0 | replace: "#", "" }}ee)",
    fail_color_alt = "rgba({{ colors.primary.default.hex | set_hue: 300.0 | set_saturation: 72.0 | set_lightness: 55.0 | replace: "#", "" }}ee)",
    font_color = "rgba({{ colors.on_surface.default.hex_stripped }}ff)",
    muted_color = "rgba({{ colors.on_surface_variant.default.hex_stripped }}cc)",
    bg_color = "rgba({{ colors.source_color.default.hex | set_lightness: 16.0 | set_saturation: 42.0 | replace: "#", "" }}ff)",
<* else *>
    active_border = "rgba({{ colors.primary.default.hex | set_saturation: 80.0 | set_lightness: 42.0 | replace: "#", "" }}ff)",
    active_border_alt = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 38.0 | replace: "#", "" }}ff)",
    inactive_border = "rgba({{ colors.outline.default.hex_stripped }}cc)",
    window_shadow = "rgba({{ colors.source_color.default.hex | set_lightness: 12.0 | set_saturation: 22.0 | replace: "#", "" }}33)",
    input_inner = "rgba({{ colors.primary.default.hex | set_saturation: 35.0 | set_lightness: 86.0 | replace: "#", "" }}8c)",
    check_color = "rgba({{ colors.primary.default.hex | set_hue: 140.0 | set_saturation: 78.0 | set_lightness: 38.0 | replace: "#", "" }}ff)",
    check_color_alt = "rgba({{ colors.primary.default.hex | set_hue: 48.0 | set_saturation: 90.0 | set_lightness: 42.0 | replace: "#", "" }}ff)",
    fail_color = "rgba({{ colors.primary.default.hex | set_hue: 8.0 | set_saturation: 88.0 | set_lightness: 42.0 | replace: "#", "" }}ff)",
    fail_color_alt = "rgba({{ colors.primary.default.hex | set_hue: 300.0 | set_saturation: 72.0 | set_lightness: 42.0 | replace: "#", "" }}ff)",
    font_color = "rgba({{ colors.on_surface.default.hex | set_lightness: 8.0 | replace: "#", "" }}ff)",
    muted_color = "rgba({{ colors.on_surface_variant.default.hex | set_lightness: 28.0 | replace: "#", "" }}cc)",
    bg_color = "rgba({{ colors.source_color.default.hex | set_lightness: 96.0 | set_saturation: 12.0 | replace: "#", "" }}ff)",
<* endif *>
}
