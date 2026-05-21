#!/bin/sh

set -eu

[ -f "$HOME/.config/hypr/hyprpaper.conf" ] || exit 0
command -v hyprpaper >/dev/null 2>&1 || exit 0

current_theme_file="$HOME/.config/bsdrunner/current-theme"
theme="default"

if [ -f "$current_theme_file" ]; then
    theme="$(tr -d '\n' < "$current_theme_file")"
fi

wallpaper_dir="$HOME/.config/bsdrunner/themes/$theme/wallpapers"

hyprpaper >/dev/null 2>&1 &

[ -d "$wallpaper_dir" ] || exit 0

wallpapers="$(find "$wallpaper_dir" -maxdepth 1 -type f | sort)"
[ -n "$wallpapers" ] || exit 0

wallpaper_count="$(printf '%s\n' "$wallpapers" | sed '/^$/d' | wc -l | tr -d ' ')"
[ "${wallpaper_count:-0}" -gt 0 ] || exit 0

monitor_names() {
    hyprctl monitors -j 2>/dev/null |
        tr '\n' ' ' |
        sed 's/},{/}\n{/g' |
        sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

active_workspace_id() {
    hyprctl activeworkspace -j 2>/dev/null |
        tr '\n' ' ' |
        sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9][0-9]*\).*/\1/p' |
        head -n 1
}

wallpaper_for_workspace() {
    workspace_id="$1"
    index=$(( (workspace_id - 1) % wallpaper_count + 1 ))
    printf '%s\n' "$wallpapers" | sed -n "${index}p"
}

apply_workspace_wallpaper() {
    workspace_id="$1"
    [ "$workspace_id" -gt 0 ] 2>/dev/null || return 0

    wallpaper_path="$(wallpaper_for_workspace "$workspace_id")"
    [ -n "$wallpaper_path" ] || return 0

    monitor_names | while IFS= read -r monitor_name; do
        [ -n "$monitor_name" ] || continue
        hyprctl hyprpaper wallpaper "$monitor_name,$wallpaper_path" >/dev/null 2>&1 || true
    done
}

sleep 1

printf '%s\n' "$wallpapers" | while IFS= read -r wallpaper_path; do
    [ -n "$wallpaper_path" ] || continue
    hyprctl hyprpaper preload "$wallpaper_path" >/dev/null 2>&1 || true
done

last_workspace_id=""

while :; do
    workspace_id="$(active_workspace_id || true)"
    if [ -n "$workspace_id" ] && [ "$workspace_id" != "$last_workspace_id" ]; then
        apply_workspace_wallpaper "$workspace_id"
        last_workspace_id="$workspace_id"
    fi
    sleep 1
done
