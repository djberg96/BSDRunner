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

mkdir -p "$HOME/.config/rofi"
mkdir -p "$HOME/.config/waybar"

printf '%s\n' "$theme" > "$HOME/.config/bsdrunner/current-theme"

cat \
    "$repo_root/dotfiles/.config/kitty/kitty.conf" \
    "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/kitty.conf" \
    > "$HOME/.config/kitty/kitty.conf"

cp "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/rofi.rasi" \
   "$HOME/.config/rofi/config.rasi"

cat \
    "$repo_root/dotfiles/.config/waybar/style.css" \
    "$repo_root/dotfiles/.config/bsdrunner/themes/$theme/waybar.css" \
    > "$HOME/.config/waybar/style.css"

echo ":: Installed BSDRunner dotfiles into $HOME"
echo ":: Applied BSDRunner theme: $theme"
