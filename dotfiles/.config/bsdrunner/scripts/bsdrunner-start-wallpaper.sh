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

if swww-daemon --help 2>/dev/null | grep -q -- '--no-cache'; then
    swww-daemon --no-cache >/dev/null 2>&1 &
else
    swww-daemon >/dev/null 2>&1 &
fi
sleep 1

theme_wallpapers() {
    find "$wallpaper_dir" -maxdepth 1 -type f \
        ! -name '*.pre-bsdrunner*' \
        \( -iname '*.gif' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
}

preferred_wallpaper_for_stem() {
    stem="$1"

    if [ "${wallpaper_path%.*}" = "$stem" ] && [ -f "$wallpaper_path" ]; then
        printf '%s\n' "$wallpaper_path"
        return 0
    fi

    if [ -f "${stem}.gif" ]; then
        printf '%s\n' "${stem}.gif"
        return 0
    fi

    for ext in jpg jpeg png webp; do
        candidate="${stem}.${ext}"
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
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

active_workspace_slot() {
    workspace_json="$(hyprctl activeworkspace -j 2>/dev/null | tr '\n' ' ')"

    workspace_name="$(printf '%s\n' "$workspace_json" |
        sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\(-\{0,1\}[0-9][0-9]*\)".*/\1/p' |
        head -n 1)"
    if [ -n "$workspace_name" ]; then
        printf '%s\n' "$workspace_name"
        return 0
    fi

    printf '%s\n' "$workspace_json" |
        sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\{0,1\}\(-\{0,1\}[0-9][0-9]*\)"\{0,1\}.*/\1/p' |
        head -n 1
}

ordered_wallpapers() {
    current_stem="${wallpaper_path%.*}"
    preferred_wallpaper_for_stem "$current_stem" || true

    theme_wallpapers | while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        stem="${candidate%.*}"
        [ "$stem" = "$current_stem" ] && continue
        printf '%s\n' "$stem"
    done | sort -u | while IFS= read -r stem; do
        [ -n "$stem" ] || continue
        preferred_wallpaper_for_stem "$stem" || true
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
        if [ -n "$override_wallpaper" ] &&
           [ -f "$override_wallpaper" ] &&
           [ "${override_wallpaper%.*}" = "${default_wallpaper%.*}" ]; then
            printf '%s\n' "$override_wallpaper"
            return 0
        fi
    fi

    printf '%s\n' "$default_wallpaper"
}

apply_workspace_wallpaper() {
    workspace_id="$1"
    if ! [ "$workspace_id" -gt 0 ] 2>/dev/null; then
        swww img "$wallpaper_path" >/dev/null 2>&1 || true
        return 0
    fi

    target_wallpaper="$(wallpaper_for_workspace "$workspace_id" || true)"
    if [ -z "$target_wallpaper" ]; then
        target_wallpaper="$wallpaper_path"
    fi

    swww img "$target_wallpaper" >/dev/null 2>&1 || true
}

last_workspace_id=""

# Paint something immediately so a slow/empty hyprctl response does not leave
# the desktop blank after restarting swww-daemon.
apply_workspace_wallpaper "$(active_workspace_slot || true)"

while :; do
    workspace_id="$(active_workspace_slot || true)"
    if [ -n "$workspace_id" ] && [ "$workspace_id" != "$last_workspace_id" ]; then
        apply_workspace_wallpaper "$workspace_id"
        last_workspace_id="$workspace_id"
    fi
    sleep 1
done
