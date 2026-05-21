#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="default"

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
    local active_border=""
    local inactive_border=""

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--theme)
            [[ $# -ge 2 ]] || {
                echo ":: Missing theme name for $1" >&2
                usage
                exit 1
            }
            theme="$2"
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

if ! theme_exists "$theme"; then
    echo ":: Unknown theme: $theme" >&2
    usage
    exit 1
fi

rsync -a --backup --suffix='.pre-bsdrunner' "$repo_root/dotfiles/" "$HOME/"

mkdir -p "$HOME/.config/bsdrunner/base"
mkdir -p "$HOME/.config/hypr"
mkdir -p "$HOME/.config/rofi"
mkdir -p "$HOME/.config/waybar"

printf '%s\n' "$theme" > "$HOME/.config/bsdrunner/current-theme"

cp "$repo_root/dotfiles/.config/kitty/kitty.conf" \
   "$HOME/.config/bsdrunner/base/kitty.conf"

cp "$repo_root/dotfiles/.config/waybar/style.css" \
   "$HOME/.config/bsdrunner/base/waybar.css"

cp "$repo_root/dotfiles/.config/waybar/config" \
   "$HOME/.config/bsdrunner/base/waybar-config"

write_hypr_theme "$HOME/.config/hypr/bsdrunner-theme.conf" "$theme"

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
