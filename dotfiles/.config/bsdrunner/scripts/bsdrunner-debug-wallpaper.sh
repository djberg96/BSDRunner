#!/bin/sh

set -eu

runner_home="$HOME/.config/bsdrunner"
wallpaper_file="$runner_home/current-wallpaper"
theme_file="$runner_home/current-theme"

[ -f "$wallpaper_file" ] || {
    echo "missing: $wallpaper_file" >&2
    exit 1
}

wallpaper_path="$(tr -d '\n' < "$wallpaper_file")"
[ -n "$wallpaper_path" ] || {
    echo "empty current-wallpaper" >&2
    exit 1
}
[ -f "$wallpaper_path" ] || {
    echo "missing wallpaper asset: $wallpaper_path" >&2
    exit 1
}

wallpaper_dir="$(dirname "$wallpaper_path")"

current_theme() {
    if [ -f "$theme_file" ]; then
        tr -d '\n' < "$theme_file"
    else
        printf '%s' "default"
    fi
}

theme_wallpapers() {
    find "$wallpaper_dir" -maxdepth 1 -type f | sort
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

ordered_wallpapers() {
    current_stem="${wallpaper_path%.*}"
    last_stem="$current_stem"

    preferred_wallpaper_for_stem "$current_stem" || true

    theme_wallpapers | while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        stem="${candidate%.*}"
        [ "$stem" = "$last_stem" ] && continue
        last_stem="$stem"
        [ "$stem" = "$current_stem" ] && continue
        preferred_wallpaper_for_stem "$stem" || true
    done
}

wallpaper_for_workspace() {
    workspace_id="$1"
    wallpaper_count="$(ordered_wallpapers | sed '/^$/d' | wc -l | tr -d ' ')"
    [ "${wallpaper_count:-0}" -gt 0 ] || return 1
    index=$(( (workspace_id - 1) % wallpaper_count + 1 ))
    ordered_wallpapers | sed -n "${index}p"
}

echo "theme: $(current_theme)"
echo "current-wallpaper: $wallpaper_path"
echo "ordered-wallpapers:"

slot=1
ordered_wallpapers | while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    echo "  $slot -> $(basename "$candidate")"
    slot=$((slot + 1))
done

echo "workspace-mapping:"
for workspace_id in 1 2 3 4; do
    resolved="$(wallpaper_for_workspace "$workspace_id" || true)"
    if [ -n "$resolved" ]; then
        echo "  $workspace_id -> $(basename "$resolved")"
    else
        echo "  $workspace_id -> <none>"
    fi
done
