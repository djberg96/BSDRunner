#!/bin/sh

set -eu

wallpaper_file="$HOME/.config/bsdrunner/current-wallpaper"
[ -f "$wallpaper_file" ] || exit 0
command -v swww-daemon >/dev/null 2>&1 || exit 0
command -v swww >/dev/null 2>&1 || exit 0

wallpaper_path="$(tr -d '\n' < "$wallpaper_file")"
[ -n "$wallpaper_path" ] || exit 0
[ -f "$wallpaper_path" ] || exit 0

pkill swww-daemon >/dev/null 2>&1 || true

swww-daemon >/dev/null 2>&1 &
sleep 1

exec swww img "$wallpaper_path"
