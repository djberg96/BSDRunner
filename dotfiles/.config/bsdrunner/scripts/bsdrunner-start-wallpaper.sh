#!/bin/sh

set -eu

wallpaper_file="$HOME/.config/bsdrunner/current-wallpaper"
theme_file="$HOME/.config/bsdrunner/current-theme"
[ -f "$wallpaper_file" ] || exit 0
command -v swww-daemon >/dev/null 2>&1 || exit 0
command -v swww >/dev/null 2>&1 || exit 0

wallpaper_path="$(tr -d '\n' < "$wallpaper_file")"
[ -n "$wallpaper_path" ] || exit 0
[ -f "$wallpaper_path" ] || exit 0

wallpaper_dir="$(dirname "$wallpaper_path")"

pkill swww-daemon >/dev/null 2>&1 || true

swww-daemon >/dev/null 2>&1 &
sleep 1

theme_wallpapers() {
    find "$wallpaper_dir" -maxdepth 1 -type f | sort
}

current_theme() {
    if [ -f "$theme_file" ]; then
        tr -d '\n' < "$theme_file"
    else
        printf '%s' "default"
    fi
}

workspace_override_file() {
    workspace_id="$1"
    theme_name="$(current_theme)"
    printf '%s\n' "$HOME/.config/bsdrunner/wallpaper-overrides/$theme_name/workspace-$workspace_id"
}

active_workspace_id() {
    hyprctl activeworkspace -j 2>/dev/null |
        tr '\n' ' ' |
        sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9][0-9]*\).*/\1/p' |
        head -n 1
}

ordered_wallpapers() {
    printf '%s\n' "$wallpaper_path"
    theme_wallpapers | while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        [ "$candidate" = "$wallpaper_path" ] && continue
        printf '%s\n' "$candidate"
    done
}

wallpaper_for_workspace() {
    workspace_id="$1"
    wallpaper_count="$(ordered_wallpapers | sed '/^$/d' | wc -l | tr -d ' ')"
    [ "${wallpaper_count:-0}" -gt 0 ] || return 1
    index=$(( (workspace_id - 1) % wallpaper_count + 1 ))
    default_wallpaper="$(ordered_wallpapers | sed -n "${index}p")"
    override_file="$(workspace_override_file "$workspace_id")"

    if [ -f "$override_file" ]; then
        override_wallpaper="$(tr -d '\n' < "$override_file")"
        if [ -n "$override_wallpaper" ] && [ -f "$override_wallpaper" ]; then
            printf '%s\n' "$override_wallpaper"
            return 0
        fi
    fi

    printf '%s\n' "$default_wallpaper"
}

apply_workspace_wallpaper() {
    workspace_id="$1"
    [ "$workspace_id" -gt 0 ] 2>/dev/null || return 0

    target_wallpaper="$(wallpaper_for_workspace "$workspace_id" || true)"
    [ -n "$target_wallpaper" ] || return 0

    swww img "$target_wallpaper" >/dev/null 2>&1 || true
}

last_workspace_id=""

while :; do
    workspace_id="$(active_workspace_id || true)"
    if [ -n "$workspace_id" ] && [ "$workspace_id" != "$last_workspace_id" ]; then
        apply_workspace_wallpaper "$workspace_id"
        last_workspace_id="$workspace_id"
    fi
    sleep 1
done
