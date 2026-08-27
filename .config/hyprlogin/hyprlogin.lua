---@module 'hl'

local colors = require("colors")

-- sample hyprlogin.conf
--
-- rendered text in all widgets supports pango markup (e.g. <b> or <i> tags)
--
-- shortcuts:
-- - ESC on an empty password field returns to username entry
-- - ESC / Ctrl+U / Ctrl+Backspace clear the current field
-- - Tab / Shift+Tab cycle the selected session
--
-- Install this file to /etc/hyprlogin/hyprlogin.conf (greeter cannot read $HOME).
-- If that file does not exist, hyprlogin falls back to the installed example.
--
-- optional greeter defaults:
-- sessions:default_user = your_username
-- sessions:default_session = hyprland.desktop
--

hl.config({
    sessions = {
        default_user = "razj",
        default_session = "hyprland.desktop",
    },
})

local font = "Monospace"

hl.config({
    general = {
        hide_cursor = false,
        immediate_render = true,
        exit_command = "hyprctl dispatch exit",
        fail_timeout = 4000,
        debug_mode = false,
        debug_log_path = "/tmp/hyprlogin-debug.log",
    },
})

-- uncomment to enable fingerprint authentication
-- auth {
--     fingerprint {
--         enabled = true
--         ready_message = Scan fingerprint to unlock
--         present_message = Scanning...
--         retry_delay = 250 # in milliseconds
--     }
-- }

hl.config({
    animations = {
        enabled = true,
    },
})
hl.curve("linear", {
    type = "bezier",
    points = { { 1, 1 }, { 0, 0 } },
})
hl.animation({ leaf = "fadeIn", enabled = true, speed = 5, bezier = "linear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 5, bezier = "linear" })
hl.animation({ leaf = "inputFieldDots", enabled = true, speed = 2, bezier = "linear" })

hl.config({
    background = {
        path = "/usr/share/hypr/wall2.png",
        color = colors.bg_color,
        blur_passes = 3,
    },
})

hl.config({
    ["input-field"] = {
        size = { "20%", "5%" },
        outline_thickness = 3,
        inner_color = colors.inner_color,
        outer_color = { colors = { colors.active_border, colors.active_border_alt }, angle = 45 },
        check_color = { colors = { colors.check_color, colors.check_color_alt }, angle = 120 },
        fail_color = { colors = { colors.fail_color, colors.fail_color_alt }, angle = 40 },
        font_color = colors.font_color,
        fade_on_empty = false,
        rounding = 15,
        font_family = font,
        placeholder_text = "Input password...",
        placeholder_text_username = "Input username...",
        fail_text = "$FAIL",
        -- check_text = Authenticating...
        -- uncomment to use a letter instead of a dot to indicate the typed password
        -- dots_text_format = *
        -- dots_size = 0.4
        dots_spacing = 0.3,
        -- uncomment to use an input indicator that does not show the password length (similar to swaylock's input indicator)
        -- hide_input = true
        position = { 0, -20 },
        halign = "center",
        valign = "center",
    },
})

hl.config({
    label = {
        text = "$TIME",
        color = colors.font_color,
        font_size = 90,
        font_family = font,
        position = { -30, 0 },
        halign = "right",
        valign = "top",
    },
})

hl.config({
    label = {
        text = "cmd[update:60000] date +\"%A, %d %B %Y\"",
        color = colors.font_color,
        font_size = 25,
        font_family = font,
        position = { -30, -150 },
        halign = "right",
        valign = "top",
    },
})

hl.config({
    label = {
        text = "$LAYOUT[en,ru]",
        color = colors.muted_color,
        font_size = 24,
        onclick = "hyprctl switchxkblayout all next",
        position = { 250, -20 },
        halign = "center",
        valign = "center",
    },
})

hl.config({
    label = {
        text = "$GREETD_SESSION",
        font_size = 16,
        color = colors.muted_color,
        font_family = font,
        onclick = "hyprlogin:session_next",
        position = { 30, 30 },
        halign = "left",
        valign = "bottom",
    },
})

-- A greet message that only appears after a username is entered or set via
-- sessions:default_user. See hide_when_empty below.

hl.config({
    label = {
        text = "Login as $GREETD_USER",
        color = colors.font_color,
        font_size = 16,
        font_family = font,
        position = { 0, 20 },
        halign = "center",
        valign = "center",
        hide_when_empty = true,
    },
})
