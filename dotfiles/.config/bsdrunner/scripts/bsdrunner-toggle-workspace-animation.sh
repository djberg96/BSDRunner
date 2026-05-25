#!/bin/sh

set -eu

mode="${1:-toggle}"
runner_home="$HOME/.config/bsdrunner"
wallpaper_file="$runner_home/current-wallpaper"
theme_file="$runner_home/current-theme"

[ -f "$wallpaper_file" ] || exit 0
command -v hyprctl >/dev/null 2>&1 || exit 0
command -v swww >/dev/null 2>&1 || exit 0

wallpaper_path="$(tr -d '\n' < "$wallpaper_file")"
[ -n "$wallpaper_path" ] || exit 0
[ -f "$wallpaper_path" ] || exit 0

wallpaper_dir="$(dirname "$wallpaper_path")"

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
    printf '%s\n' "$runner_home/wallpaper-overrides/$theme_name/workspace-$workspace_id"
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
    {
        printf '%s\n' "$current_stem"
        theme_wallpapers | while IFS= read -r candidate; do
            [ -n "$candidate" ] || continue
            stem="${candidate%.*}"
            [ "$stem" = "$current_stem" ] && continue
            printf '%s\n' "$stem"
        done
    } | uniq | while IFS= read -r stem; do
        [ -n "$stem" ] || continue
        preferred_wallpaper_for_stem "$stem" || true
    done
}

default_wallpaper_for_workspace() {
    workspace_id="$1"
    wallpaper_count="$(ordered_wallpapers | sed '/^$/d' | wc -l | tr -d ' ')"
    [ "${wallpaper_count:-0}" -gt 0 ] || return 1
    index=$(( (workspace_id - 1) % wallpaper_count + 1 ))
    ordered_wallpapers | sed -n "${index}p"
}

find_gif_for_stem() {
    stem="$1"
    if [ -f "${stem}.gif" ]; then
        printf '%s\n' "${stem}.gif"
    fi
}

find_static_for_stem() {
    stem="$1"

    for ext in jpg jpeg png webp; do
        candidate="${stem}.${ext}"
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

print_status() {
    state="$1"

    case "$state" in
        active)
            text=""
            tooltip="Pause animated wallpaper for this workspace"
            class="active"
            ;;
        paused)
            text=""
            tooltip="Resume animated wallpaper for this workspace"
            class="paused"
            ;;
        *)
            text=""
            tooltip="No animated wallpaper on this workspace"
            class="unavailable"
            ;;
    esac

    printf '{'
    printf '"text":"%s",' "$text"
    printf '"tooltip":"%s",' "$tooltip"
    printf '"class":"%s"' "$class"
    printf '}\n'
}

workspace_id="$(active_workspace_slot || true)"
[ -n "$workspace_id" ] || exit 0
[ "$workspace_id" -gt 0 ] 2>/dev/null || exit 0

default_wallpaper="$(default_wallpaper_for_workspace "$workspace_id" || true)"
[ -n "$default_wallpaper" ] || exit 0

override_file="$(workspace_override_file "$workspace_id")"
effective_wallpaper="$default_wallpaper"

if [ -f "$override_file" ]; then
    override_wallpaper="$(tr -d '\n' < "$override_file")"
    if [ -n "$override_wallpaper" ] &&
       [ -f "$override_wallpaper" ] &&
       [ "${override_wallpaper%.*}" = "${default_wallpaper%.*}" ]; then
        effective_wallpaper="$override_wallpaper"
    fi
fi

default_stem="${default_wallpaper%.*}"
gif_wallpaper="$(find_gif_for_stem "$default_stem" || true)"
static_wallpaper="$(find_static_for_stem "$default_stem" || true)"

if [ -z "$gif_wallpaper" ] || [ -z "$static_wallpaper" ]; then
    effective_stem="${effective_wallpaper%.*}"
    gif_wallpaper="$(find_gif_for_stem "$effective_stem" || true)"
    static_wallpaper="$(find_static_for_stem "$effective_stem" || true)"
fi

if [ -z "$gif_wallpaper" ] || [ -z "$static_wallpaper" ]; then
    if [ "$mode" = "status" ]; then
        print_status "unavailable"
        exit 0
    fi
    exit 0
fi

if [ "$mode" = "status" ]; then
    if [ "$effective_wallpaper" = "$gif_wallpaper" ]; then
        print_status "active"
    else
        print_status "paused"
    fi
    exit 0
fi

override_dir="$(dirname "$override_file")"
mkdir -p "$override_dir"

if [ "$effective_wallpaper" = "$gif_wallpaper" ]; then
    printf '%s\n' "$static_wallpaper" > "$override_file"
    target_wallpaper="$static_wallpaper"
else
    if [ "$default_wallpaper" = "$gif_wallpaper" ]; then
        rm -f "$override_file"
    else
        printf '%s\n' "$gif_wallpaper" > "$override_file"
    fi
    target_wallpaper="$gif_wallpaper"
fi

swww img "$target_wallpaper" >/dev/null 2>&1 || true
