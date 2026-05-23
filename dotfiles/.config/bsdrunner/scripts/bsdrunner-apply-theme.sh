#!/bin/sh

set -eu

theme="${1:-}"
config_home="$HOME/.config"
runner_home="$config_home/bsdrunner"
theme_dir="$runner_home/themes/$theme"
base_dir="$runner_home/base"
lock_dir="$runner_home/.theme-apply.lock"

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

write_hypr_theme() {
    target="$1"
    selected_theme="$2"

    case "$selected_theme" in
        jinteki)
            active_border='rgba(c61f3aee) rgba(7f1325ee) 45deg'
            inactive_border='rgba(6a2a35cc)'
            ;;
        haas-bioroid)
            active_border='rgba(2f5f8eee) rgba(17324aee) 45deg'
            inactive_border='rgba(344652cc)'
            ;;
        nbn)
            active_border='rgba(f3c316ee) rgba(8d6513ee) 45deg'
            inactive_border='rgba(5a4316cc)'
            ;;
        weyland)
            active_border='rgba(5d8c45ee) rgba(5b4f24ee) 45deg'
            inactive_border='rgba(45543acc)'
            ;;
        *)
            active_border='rgba(5a7fa0ee) rgba(2e4658ee) 45deg'
            inactive_border='rgba(3c4652cc)'
            ;;
    esac

    cat > "$target" <<EOF
\$bsdrunner_active_border = $active_border
\$bsdrunner_inactive_border = $inactive_border
EOF
}

cleanup() {
    rmdir "$lock_dir" 2>/dev/null || true
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

[ -f "$base_dir/waybar-config" ] || {
    echo ":: Missing base waybar config; rerun ./scripts/install-dotfiles.sh first" >&2
    exit 1
}

[ -f "$base_dir/wlogout.css" ] || {
    echo ":: Missing base wlogout.css; rerun ./scripts/install-dotfiles.sh first" >&2
    exit 1
}

if ! mkdir "$lock_dir" 2>/dev/null; then
    echo ":: Theme switch already in progress" >&2
    exit 0
fi

trap cleanup EXIT INT TERM

mkdir -p "$config_home/hypr" "$config_home/kitty" "$config_home/rofi" "$config_home/waybar"
mkdir -p "$config_home/wlogout"

printf '%s\n' "$theme" > "$runner_home/current-theme"

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

write_hypr_theme "$config_home/hypr/bsdrunner-theme.conf" "$theme"
sh "$runner_home/scripts/bsdrunner-render-matugen.sh" "$theme" "${selected_wallpaper:-}"

cat \
    "$base_dir/kitty.conf" \
    "$theme_dir/kitty.conf" \
    > "$config_home/kitty/kitty.conf"
printf '\ninclude ~/.config/kitty/colors-matugen.conf\n' >> "$config_home/kitty/kitty.conf"

cp "$theme_dir/rofi.rasi" \
   "$config_home/rofi/config.rasi"

cat \
    "$base_dir/waybar.css" \
    "$theme_dir/waybar.css" \
    "$config_home/waybar/colors-matugen.css" \
    > "$config_home/waybar/style.css"

theme_waybar_config="$theme_dir/waybar-config"

if [ -f "$theme_waybar_config" ]; then
    cp "$theme_waybar_config" "$config_home/waybar/config"
else
    cp "$base_dir/waybar-config" "$config_home/waybar/config"
fi

cat \
    "$base_dir/wlogout.css" \
    "$config_home/wlogout/colors-matugen.css" \
    > "$config_home/wlogout/style.css"

(sh "$runner_home/scripts/bsdrunner-start-waybar.sh" >/tmp/bsdrunner-waybar.log 2>&1 &) >/dev/null 2>&1

pkill -f bsdrunner-start-wallpaper.sh 2>/dev/null || true
pkill swww-daemon 2>/dev/null || true
(sh "$runner_home/scripts/bsdrunner-start-wallpaper.sh" >/tmp/bsdrunner-wallpaper.log 2>&1 &) >/dev/null 2>&1

hyprctl reload >/tmp/bsdrunner-hypr-reload.log 2>&1 || true

echo ":: Applied BSDRunner theme: $theme"
