#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="default"
theme_was_requested=false

usage() {
    cat <<'EOF'
Usage: ./scripts/install-dotfiles.sh [-t THEME|--theme THEME]

Themes:
  default
  haas-bioroid
  jinteki
  nbn
  weyland
EOF
}

theme_exists() {
    [[ -d "$repo_root/dotfiles/.config/bsdrunner/themes/$1" ]]
}

write_hypr_theme() {
    local target="$1"
    local selected_theme="$2"
    local target_dir
    local tmp_file
    local active_border=""
    local inactive_border=""

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
    local target="$1"
    local selected_theme="$2"
    local window_bg=""
    local border=""
    local button_bg=""
    local button_hover=""
    local text=""
    local lock=""
    local logout=""
    local suspend=""
    local reboot=""
    local shutdown=""
    local cancel=""

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--theme)
            [[ $# -ge 2 ]] || {
                echo ":: Missing theme name for $1" >&2
                usage
                exit 1
            }
            theme="$2"
            theme_was_requested=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo ":: Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ "$theme_was_requested" == false && -f "$HOME/.config/bsdrunner/current-theme" ]]; then
    current_theme="$(tr -d '[:space:]' < "$HOME/.config/bsdrunner/current-theme")"
    if [[ -n "$current_theme" ]] && theme_exists "$current_theme"; then
        theme="$current_theme"
    fi
fi

if ! theme_exists "$theme"; then
    echo ":: Unknown theme: $theme" >&2
    usage
    exit 1
fi

cleanup_stale_theme_waybar_configs() {
    local theme_name=""
    local repo_theme_config=""
    local home_theme_config=""

    for theme_name in default haas-bioroid jinteki nbn weyland; do
        repo_theme_config="$repo_root/dotfiles/.config/bsdrunner/themes/$theme_name/waybar-config"
        home_theme_config="$HOME/.config/bsdrunner/themes/$theme_name/waybar-config"

        if [[ ! -f "$repo_theme_config" && -f "$home_theme_config" ]]; then
            rm -f "$home_theme_config"
        fi
    done
}

sync_waybar_scripts() {
    local source_dir="$repo_root/dotfiles/.config/waybar/scripts"
    local target_dir="$HOME/.config/waybar/scripts"

    mkdir -p "$target_dir"
    cp -R "$source_dir/." "$target_dir/"
    chmod 755 "$target_dir"/*.sh 2>/dev/null || true
}

chmod_runner_scripts() {
    local target_dir="$HOME/.config/bsdrunner/scripts"

    chmod 755 "$target_dir"/*.sh 2>/dev/null || true
}

rsync -a --backup --suffix='.pre-bsdrunner' \
    --exclude='.config/bsdrunner/pf/profile.conf' \
    "$repo_root/dotfiles/" "$HOME/"
cleanup_stale_theme_waybar_configs
sync_waybar_scripts
chmod_runner_scripts

mkdir -p "$HOME/.config/bsdrunner/base"
mkdir -p "$HOME/.config/bsdrunner/pf"
mkdir -p "$HOME/.config/hypr"
mkdir -p "$HOME/.config/rofi"
mkdir -p "$HOME/.config/waybar"
mkdir -p "$HOME/.config/wlogout"

if [[ ! -f "$HOME/.config/bsdrunner/pf/profile.conf" ]]; then
    cp "$repo_root/dotfiles/.config/bsdrunner/pf/profile.conf" \
       "$HOME/.config/bsdrunner/pf/profile.conf"
fi

printf '%s\n' "$theme" > "$HOME/.config/bsdrunner/current-theme"

cp "$repo_root/dotfiles/.config/kitty/kitty.conf" \
   "$HOME/.config/bsdrunner/base/kitty.conf"

cp "$repo_root/dotfiles/.config/waybar/style.css" \
   "$HOME/.config/bsdrunner/base/waybar.css"

cp "$repo_root/dotfiles/.config/waybar/config" \
   "$HOME/.config/bsdrunner/base/waybar-config"

write_hypr_theme "$HOME/.config/hypr/bsdrunner-theme.conf" "$theme"
write_wlogout_style "$HOME/.config/wlogout/style.css" "$theme"
sh "$HOME/.config/bsdrunner/scripts/bsdrunner-apply-firefox-theme.sh" "$theme" || \
    echo ":: Firefox theme skipped" >&2

cat \
    "$HOME/.config/bsdrunner/base/kitty.conf" \
    "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/kitty.conf" \
    > "$HOME/.config/kitty/kitty.conf"

cp "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/rofi.rasi" \
   "$HOME/.config/rofi/config.rasi"

cat \
    "$HOME/.config/bsdrunner/base/waybar.css" \
    "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/waybar.css" \
    > "$HOME/.config/waybar/style.css"

theme_waybar_config="$repo_root/dotfiles/.config/bsdrunner/themes/$theme/waybar-config"

if [[ -f "$theme_waybar_config" ]]; then
    cp "$theme_waybar_config" "$HOME/.config/waybar/config"
else
    cp "$HOME/.config/bsdrunner/base/waybar-config" "$HOME/.config/waybar/config"
fi

theme_wallpaper_dir="$repo_root/dotfiles/.config/bsdrunner/themes/$theme/wallpapers"
active_wallpaper_dir="$HOME/.config/bsdrunner/themes/$theme/wallpapers"

if [[ -d "$theme_wallpaper_dir" ]] && find "$theme_wallpaper_dir" -maxdepth 1 -type f | read -r _; then
    selected_wallpaper=""

    while IFS= read -r repo_wallpaper; do
        wallpaper_name="$(basename "$repo_wallpaper")"
        active_wallpaper="$active_wallpaper_dir/$wallpaper_name"
        if [[ "$theme" == "jinteki" && "$wallpaper_name" == "jinteki_wallpaper4.jpg" ]]; then
            selected_wallpaper="$active_wallpaper"
        elif [[ -z "$selected_wallpaper" ]]; then
            selected_wallpaper="$active_wallpaper"
        fi
    done < <(find "$theme_wallpaper_dir" -maxdepth 1 -type f | sort)

    printf '%s\n' "$selected_wallpaper" > "$HOME/.config/bsdrunner/current-wallpaper"
else
    rm -f "$HOME/.config/bsdrunner/current-wallpaper"
fi

echo ":: Installed BSDRunner dotfiles into $HOME"
echo ":: Applied BSDRunner theme: $theme"
