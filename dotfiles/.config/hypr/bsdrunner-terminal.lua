-- Minimal Hyprland session for the BSDRunner Terminal login target.

hl.on("hyprland.start", function()
    hl.exec_cmd("sh ~/.config/bsdrunner/scripts/bsdrunner-run-terminal-session.sh")
end)

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    general = {
        border_size = 0,
        gaps_in = 0,
        gaps_out = 0,
        resize_on_border = false,
    },
    decoration = {
        rounding = 0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
        },
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

hl.bind("SUPER + Escape", hl.dsp.exit())
