#!/bin/sh

set -eu

theme="${1:-}"
config_home="$HOME/.config"
runner_home="$config_home/bsdrunner"
theme_dir="$runner_home/themes/$theme"
base_dir="$runner_home/base"

usage() {
    cat <<'EOF' >&2
Usage: sh ~/.config/bsdrunner/scripts/bsdrunner-apply-theme.sh THEME

Themes:
  default
  haas-bioroid
  jinteki
  nbn
  weyland
EOF
}

[ -n "$theme" ] || {
    usage
    exit 1
}

[ -d "$theme_dir" ] || {
    echo ":: Unknown theme: $theme" >&2
    usage
    exit 1
}

[ -f "$base_dir/kitty.conf" ] || {
    echo ":: Missing base kitty.conf; rerun ./scripts/install-dotfiles.sh first" >&2
    exit 1
}

[ -f "$base_dir/waybar.css" ] || {
    echo ":: Missing base waybar.css; rerun ./scripts/install-dotfiles.sh first" >&2
    exit 1
}

mkdir -p "$config_home/kitty" "$config_home/rofi" "$config_home/waybar"

printf '%s\n' "$theme" > "$runner_home/current-theme"

cat \
    "$base_dir/kitty.conf" \
    "$theme_dir/kitty.conf" \
    > "$config_home/kitty/kitty.conf"

cp "$theme_dir/rofi.rasi" \
   "$config_home/rofi/config.rasi"

cat \
    "$base_dir/waybar.css" \
    "$theme_dir/waybar.css" \
    > "$config_home/waybar/style.css"

theme_wallpaper_dir="$theme_dir/wallpapers"

if [ -d "$theme_wallpaper_dir" ] && find "$theme_wallpaper_dir" -maxdepth 1 -type f | read -r _; then
    selected_wallpaper=""

    while IFS= read -r active_wallpaper; do
        wallpaper_name="$(basename "$active_wallpaper")"
        if [ "$theme" = "jinteki" ] && [ "$wallpaper_name" = "jinteki_wallpaper4.jpg" ]; then
            selected_wallpaper="$active_wallpaper"
        elif [ -z "$selected_wallpaper" ]; then
            selected_wallpaper="$active_wallpaper"
        fi
    done <<EOF
$(find "$theme_wallpaper_dir" -maxdepth 1 -type f | sort)
EOF

    printf '%s\n' "$selected_wallpaper" > "$runner_home/current-wallpaper"
else
    rm -f "$runner_home/current-wallpaper"
fi

pkill waybar 2>/dev/null || true
(dbus-launch waybar >/tmp/bsdrunner-waybar.log 2>&1 &) >/dev/null 2>&1

pkill -f bsdrunner-start-wallpaper.sh 2>/dev/null || true
pkill swww-daemon 2>/dev/null || true
(sh "$runner_home/scripts/bsdrunner-start-wallpaper.sh" >/tmp/bsdrunner-wallpaper.log 2>&1 &) >/dev/null 2>&1

echo ":: Applied BSDRunner theme: $theme"
