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
    target_dir="$(dirname "$target")"
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-hypr-theme.XXXXXX")"

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

    cat > "$tmp_file" <<EOF
\$bsdrunner_active_border = $active_border
\$bsdrunner_inactive_border = $inactive_border
EOF

    mkdir -p "$target_dir"
    mv "$tmp_file" "$target"
}

write_wlogout_style() {
    target="$1"
    selected_theme="$2"

    case "$selected_theme" in
        jinteki)
            window_bg='rgba(6, 4, 5, 0.92)'
            border='rgba(198, 31, 58, 0.65)'
            button_bg='rgba(28, 15, 18, 0.995)'
            button_hover='rgba(98, 23, 36, 1.0)'
            text='#fff1f3'
            lock='#ffd7dd'
            logout='#ffc7cf'
            suspend='#ffb36b'
            reboot='#ff8795'
            shutdown='#ff6f83'
            cancel='#f7e2e5'
            ;;
        haas-bioroid)
            window_bg='rgba(6, 10, 14, 0.92)'
            border='rgba(47, 95, 142, 0.72)'
            button_bg='rgba(16, 23, 31, 0.995)'
            button_hover='rgba(28, 53, 78, 1.0)'
            text='#eef7ff'
            lock='#b9d8f2'
            logout='#95c8ee'
            suspend='#f0c674'
            reboot='#e39090'
            shutdown='#ff7a7a'
            cancel='#d7e9f8'
            ;;
        nbn)
            window_bg='rgba(16, 12, 4, 0.92)'
            border='rgba(243, 195, 22, 0.72)'
            button_bg='rgba(34, 25, 8, 0.995)'
            button_hover='rgba(118, 82, 12, 1.0)'
            text='#fff8df'
            lock='#ffe69b'
            logout='#ffd36f'
            suspend='#ffb45f'
            reboot='#ff9d4d'
            shutdown='#ff7c3f'
            cancel='#fff0bd'
            ;;
        weyland)
            window_bg='rgba(8, 10, 5, 0.92)'
            border='rgba(93, 140, 69, 0.72)'
            button_bg='rgba(22, 28, 14, 0.995)'
            button_hover='rgba(57, 79, 33, 1.0)'
            text='#f2f7e8'
            lock='#c7ddb1'
            logout='#b0d38c'
            suspend='#d0c27a'
            reboot='#d89f5f'
            shutdown='#db7b55'
            cancel='#dde9cf'
            ;;
        *)
            window_bg='rgba(8, 12, 16, 0.92)'
            border='rgba(90, 127, 160, 0.72)'
            button_bg='rgba(18, 24, 30, 0.995)'
            button_hover='rgba(43, 69, 91, 1.0)'
            text='#eef5fb'
            lock='#d3e5f4'
            logout='#bdd6eb'
            suspend='#e2c27a'
            reboot='#d9a27f'
            shutdown='#d97f7f'
            cancel='#dfeaf3'
            ;;
    esac

    cat > "$target" <<EOF
window {
    background-color: $window_bg;
}

button {
    background-image: none;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 0%;
    border: 2px solid $border;
    border-radius: 22px;
    background-color: $button_bg;
    color: $text;
    font-family: "JetBrains Mono";
    font-size: 24px;
    font-weight: 800;
    margin: 14px;
    min-width: 150px;
    min-height: 150px;
    box-shadow: none;
    text-shadow: none;
    padding: 0;
}

button:hover {
    background-color: $button_hover;
    border-color: $text;
}

button:focus {
    background-color: $button_hover;
    border-color: $text;
    color: #ffffff;
}

#lock { color: $lock; }
#logout { color: $logout; }
#suspend { color: $suspend; }
#reboot { color: $reboot; }
#shutdown { color: $shutdown; }
#cancel { color: $cancel; }
EOF
}

sync_waybar_scripts() {
    source_dir="$runner_home/../waybar/scripts"
    target_dir="$config_home/waybar/scripts"
    resolved_source_dir="$(cd "$source_dir" 2>/dev/null && pwd -P || printf '%s\n' "$source_dir")"
    resolved_target_dir="$(cd "$target_dir" 2>/dev/null && pwd -P || printf '%s\n' "$target_dir")"

    mkdir -p "$target_dir"
    if [ "$resolved_source_dir" = "$resolved_target_dir" ]; then
        return 0
    fi
    cp -R "$source_dir/." "$target_dir/"
    chmod 755 "$target_dir"/*.sh 2>/dev/null || true
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

if ! mkdir "$lock_dir" 2>/dev/null; then
    echo ":: Theme switch already in progress" >&2
    exit 0
fi

trap cleanup EXIT INT TERM

mkdir -p "$config_home/hypr" "$config_home/kitty" "$config_home/rofi" "$config_home/waybar" "$config_home/wlogout"
sync_waybar_scripts

printf '%s\n' "$theme" > "$runner_home/current-theme"

write_hypr_theme "$config_home/hypr/bsdrunner-theme.conf" "$theme"
write_wlogout_style "$config_home/wlogout/style.css" "$theme"
sh "$runner_home/scripts/bsdrunner-apply-firefox-theme.sh" "$theme" || \
    echo ":: Firefox theme skipped" >&2

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

theme_waybar_config="$theme_dir/waybar-config"

if [ -f "$theme_waybar_config" ]; then
    cp "$theme_waybar_config" "$config_home/waybar/config"
else
    cp "$base_dir/waybar-config" "$config_home/waybar/config"
fi

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

(sh "$runner_home/scripts/bsdrunner-start-waybar.sh" >/tmp/bsdrunner-waybar.log 2>&1 &) >/dev/null 2>&1

pkill -f bsdrunner-start-wallpaper.sh 2>/dev/null || true
pkill swww-daemon 2>/dev/null || true
(sh "$runner_home/scripts/bsdrunner-start-wallpaper.sh" >/tmp/bsdrunner-wallpaper.log 2>&1 &) >/dev/null 2>&1

hyprctl reload >/tmp/bsdrunner-hypr-reload.log 2>&1 || true

echo ":: Applied BSDRunner theme: $theme"
