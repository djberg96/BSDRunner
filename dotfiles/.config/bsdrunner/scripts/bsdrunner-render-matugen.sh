#!/bin/sh

set -eu

config_home="$HOME/.config"
runner_home="$config_home/bsdrunner"
theme="${1:-}"
wallpaper_path="${2:-}"

if [ -z "$theme" ] && [ -f "$runner_home/current-theme" ]; then
    theme="$(tr -d '\n' < "$runner_home/current-theme")"
fi

[ -n "$theme" ] || theme="default"

if [ -z "$wallpaper_path" ] && [ -f "$runner_home/current-wallpaper" ]; then
    wallpaper_path="$(tr -d '\n' < "$runner_home/current-wallpaper")"
fi

theme_dir="$runner_home/themes/$theme"
palette_file="$theme_dir/palette.conf"
matugen_config="$config_home/matugen/config.toml"

hypr_output="$config_home/hypr/bsdrunner-matugen.conf"
kitty_output="$config_home/kitty/colors-matugen.conf"
waybar_output="$config_home/waybar/colors-matugen.css"
wlogout_output="$config_home/wlogout/colors-matugen.css"

mkdir -p "$config_home/hypr" "$config_home/kitty" "$config_home/waybar" "$config_home/wlogout"

load_palette() {
    [ -f "$palette_file" ] || return 1
    # shellcheck disable=SC1090
    . "$palette_file"
    : "${background:?}"
    : "${surface:?}"
    : "${text:?}"
    : "${accent:?}"
    : "${accent_strong:?}"
    : "${warning:?}"
}

write_fallback_hypr() {
    cat > "$hypr_output" <<EOF
\$bsdrunner_active_border = rgba(${accent#\#}ee) rgba(${accent_strong#\#}dd) 45deg
\$bsdrunner_inactive_border = rgba(${surface#\#}cc)
\$bsdrunner_shadow_color = rgba(${background#\#}cc)
EOF
}

write_fallback_kitty() {
    cat > "$kitty_output" <<EOF
# BSDRunner palette fallback
foreground             $text
background             $surface
selection_foreground   $background
selection_background   $accent_strong

cursor                 $text
cursor_text_color      $accent
url_color              $accent

active_border_color    $accent
inactive_border_color  $surface
bell_border_color      $warning

active_tab_foreground   $background
active_tab_background   $accent
inactive_tab_foreground $text
inactive_tab_background $surface

wayland_titlebar_color $surface

color0  $background
color1  $warning
color2  $accent
color3  $warning
color4  $accent_strong
color5  $accent
color6  $accent_strong
color7  $text

color8  $surface
color9  $warning
color10 $accent_strong
color11 $warning
color12 $accent
color13 $accent_strong
color14 $text
color15 #ffffff
EOF
}

write_fallback_waybar() {
    cat > "$waybar_output" <<EOF
window#waybar {
    background: ${surface}e0;
    color: $text;
}

tooltip {
    background: ${surface}f5;
    color: $text;
    border: 1px solid ${accent}66;
}

#workspaces,
#custom-theme,
#window,
#cpu,
#memory,
#pulseaudio,
#custom-network,
#custom-battery,
#clock,
#tray,
#custom-power {
    background: ${surface}eb;
    color: $text;
    border: 1px solid ${accent}33;
}

#custom-theme,
#custom-battery.charging,
#custom-battery.full,
#clock {
    color: $accent;
}

#custom-theme:hover,
#workspaces button:hover {
    background: ${accent}22;
}

#workspaces button {
    color: $text;
}

#workspaces button.active {
    background: ${accent}33;
    color: $accent_strong;
}

#custom-network.disconnected,
#custom-battery.critical {
    color: $warning;
}

#custom-battery.warning {
    color: $warning;
}

#custom-power:hover {
    background: ${accent}22;
    border-color: ${accent_strong}77;
}
EOF
}

write_fallback_wlogout() {
    cat > "$wlogout_output" <<EOF
window {
    background-color: ${background}ea;
}

button {
    border: 2px solid ${accent}aa;
    background-color: ${surface}fd;
    color: $text;
}

button:hover {
    background-color: ${accent}ff;
    border-color: ${accent_strong}ee;
}

button:focus {
    background-color: ${accent}ff;
    border-color: ${accent_strong}ff;
    color: #ffffff;
}

#lock,
#logout,
#cancel {
    color: $text;
}

#suspend {
    color: $warning;
}

#reboot,
#shutdown {
    color: $accent_strong;
}
EOF
}

write_fallback_outputs() {
    load_palette
    write_fallback_hypr
    write_fallback_kitty
    write_fallback_waybar
    write_fallback_wlogout
}

if command -v matugen >/dev/null 2>&1 &&
   [ -f "$wallpaper_path" ] &&
   [ -f "$matugen_config" ]; then
    if matugen image "$wallpaper_path" -c "$matugen_config" >/tmp/bsdrunner-matugen.log 2>&1; then
        echo ":: Generated matugen colors from $(basename "$wallpaper_path")"
        exit 0
    fi
    echo ":: Matugen generation failed; using palette fallback" >&2
fi

write_fallback_outputs
echo ":: Wrote palette fallback colors for theme: $theme"
