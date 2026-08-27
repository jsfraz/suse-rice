---@module 'hl'

-- greetd greeter session. Configs live in /etc/hyprlogin/ (greeter cannot
-- read $HOME). Palette is copied there by matugen post_hook.

local ok, colors = pcall(require, "colors")
if not ok then
    colors = { bg_color = "rgba(111111ff)" }
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.config({
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = colors.bg_color,
    },
    input = {
        kb_layout = "cz",
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprlogin")
end)
