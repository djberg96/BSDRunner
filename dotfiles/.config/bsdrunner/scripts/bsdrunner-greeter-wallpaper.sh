#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
runner_home="$HOME/.config/bsdrunner"

if [ ! -d "$runner_home/themes" ]; then
    runner_home="$(CDPATH= cd -- "$script_dir/.." && pwd)"
fi

find "$runner_home/themes" -path '*/wallpapers/*' -type f \
    ! -name '*.pre-bsdrunner*' \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | awk '
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
