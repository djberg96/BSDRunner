-- Minimal compositor used only for the BSDRunner greetd greeter.

hl.on("hyprland.start", function()
    hl.exec_cmd("/etc/greetd/bsdrunner/launch-greeter.sh")
end)

hl.env("GTK_USE_PORTAL", "0")
hl.env("GDK_DEBUG", "no-portals")

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.config({
    input = {
        kb_layout = "us",
    },
    general = {
        border_size = 0,
        gaps_in = 0,
        gaps_out = 0,
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
        disable_hyprland_guiutils_check = true,
        force_default_wallpaper = 0,
    },
})
