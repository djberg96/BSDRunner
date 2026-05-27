#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
runner_home="$HOME/.config/bsdrunner"
theme_file="$runner_home/current-theme"

if [ ! -d "$runner_home/themes" ]; then
    runner_home="$(CDPATH= cd -- "$script_dir/.." && pwd)"
    theme_file="$runner_home/current-theme"
fi

current_theme() {
    if [ -f "$theme_file" ]; then
        tr -d '\n' < "$theme_file"
    else
        printf '%s' "default"
    fi
}

wallpaper_candidates() {
    theme_name="$(current_theme)"

    if [ -n "$theme_name" ] && [ "$theme_name" != "default" ] && [ -d "$runner_home/themes/$theme_name/wallpapers" ]; then
        find "$runner_home/themes/$theme_name/wallpapers" -maxdepth 1 -type f \
            ! -name '*.pre-bsdrunner*' \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
        return
    fi

    find "$runner_home/themes" -path '*/wallpapers/*' -type f \
        ! -name '*.pre-bsdrunner*' \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
}

wallpaper_candidates | awk '
    BEGIN {
        srand()
    }

    {
        if (rand() * NR < 1)
            pick = $0
    }

    END {
        if (pick != "")
            print pick
    }
'
