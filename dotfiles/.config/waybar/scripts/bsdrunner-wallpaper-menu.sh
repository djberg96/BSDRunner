#!/bin/sh

set -eu

command -v rofi >/dev/null 2>&1 || exit 0

config_home="$HOME/.config"
runner_home="$config_home/bsdrunner"
theme_file="$runner_home/current-theme"
wallpaper_file="$runner_home/current-wallpaper"
theme="default"

if [ -f "$theme_file" ]; then
    theme="$(tr -d '\n' < "$theme_file")"
fi

wallpaper_dir="$runner_home/themes/$theme/wallpapers"
[ -d "$wallpaper_dir" ] || exit 0

wallpaper_names="$(
    find "$wallpaper_dir" -maxdepth 1 -type f -exec basename {} \; | sort
)"

[ -n "$wallpaper_names" ] || exit 0

current_name=""
if [ -f "$wallpaper_file" ]; then
    current_name="$(basename "$(tr -d '\n' < "$wallpaper_file")")"
fi

choice="$(
    printf '%s\n' "$wallpaper_names" |
        rofi -dmenu -i -p "Wallpaper" -mesg "Theme: $theme  Current: ${current_name:-none}"
)"

[ -n "${choice:-}" ] || exit 0

selected_wallpaper="$wallpaper_dir/$choice"
[ -f "$selected_wallpaper" ] || exit 1

printf '%s\n' "$selected_wallpaper" > "$wallpaper_file"

pkill -f bsdrunner-start-wallpaper.sh 2>/dev/null || true
pkill swww-daemon 2>/dev/null || true
(sh "$runner_home/scripts/bsdrunner-start-wallpaper.sh" >/tmp/bsdrunner-wallpaper.log 2>&1 &) >/dev/null 2>&1
