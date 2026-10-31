#!/bin/sh

set -eu

bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
theme="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$bundle_dir/current-theme")"
wallpaper_dir="$bundle_dir/themes/$theme/wallpapers"
runtime_root="${XDG_RUNTIME_DIR:-/tmp}/bsdrunner-greeter"

mkdir -p "$runtime_root/cache"
chmod 700 "$runtime_root" "$runtime_root/cache"

wallpaper="$(find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort | awk '
        BEGIN { srand() }
        { if (rand() * NR < 1) pick = $0 }
        END { if (pick != "") print pick }
    ')"

export BSDRUNNER_GREETER_DIR="$bundle_dir"
export BSDRUNNER_GREETER_WALLPAPER="$wallpaper"
export XDG_CACHE_HOME="$runtime_root/cache"

set +e
qs --path "$bundle_dir/quickshell"
status="$?"
set -e

hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || true
exit "$status"
