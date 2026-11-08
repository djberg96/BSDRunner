#!/bin/sh

set -eu

bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
runtime_root="${XDG_RUNTIME_DIR:-/tmp}/bsdrunner-greeter"

mkdir -p "$runtime_root/cache"
chmod 700 "$runtime_root" "$runtime_root/cache"

wallpapers_for_theme() {
    find "$bundle_dir/themes/$1/wallpapers" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | sort
}

theme_is_eligible() {
    [ -n "$1" ] || return 1
    [ "${1#*/}" = "$1" ] || return 1
    [ -f "$bundle_dir/themes/$1/palette.conf" ] || return 1
    [ -n "$(wallpapers_for_theme "$1")" ]
}

eligible_themes() {
    for theme_dir in "$bundle_dir"/themes/*; do
        [ -d "$theme_dir" ] || continue
        candidate="$(basename -- "$theme_dir")"
        theme_is_eligible "$candidate" || continue
        printf '%s\n' "$candidate"
    done
}

random_line() {
    seed="$1"
    awk -v seed="$seed" '
        BEGIN { srand(seed) }
        { if (rand() * NR < 1) pick = $0 }
        END { if (pick != "") print pick }
    '
}

seed="$(date +%s 2>/dev/null || printf '1')"
seed=$((seed + $$))
configured_theme="${BSDRUNNER_GREETER_THEME:-}"

if theme_is_eligible "$configured_theme"; then
    theme="$configured_theme"
else
    theme="$(eligible_themes | random_line "$seed")"
fi

if [ -z "$theme" ]; then
    theme="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$bundle_dir/current-theme")"
fi

wallpaper="$(wallpapers_for_theme "$theme" | random_line "$((seed + 104729))")"

export BSDRUNNER_GREETER_DIR="$bundle_dir"
export BSDRUNNER_GREETER_THEME="$theme"
export BSDRUNNER_GREETER_WALLPAPER="$wallpaper"
export XDG_CACHE_HOME="$runtime_root/cache"

set +e
if [ -n "${BSDRUNNER_GREETER_LOG_DIR:-}" ] && [ -d "$BSDRUNNER_GREETER_LOG_DIR" ]; then
    qs --path "$bundle_dir/quickshell" >>"$BSDRUNNER_GREETER_LOG_DIR/quickshell.log" 2>&1
else
    qs --path "$bundle_dir/quickshell"
fi
status="$?"
set -e

hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1 || true
exit "$status"
