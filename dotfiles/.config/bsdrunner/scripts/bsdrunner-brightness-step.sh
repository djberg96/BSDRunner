#!/bin/sh

set -eu

case "${1:-}" in
    up) direction=up ;;
    down) direction=down ;;
    *) printf 'Usage: %s up|down\n' "$0" >&2; exit 2 ;;
esac

if [ "$(uname -s)" = FreeBSD ] && command -v backlight >/dev/null 2>&1; then
    current="$(backlight -q)"
    case "$current" in
        ''|*[!0-9]*) printf 'Unable to read the current brightness.\n' >&2; exit 1 ;;
    esac
    if [ "$direction" = up ]; then
        target=$((current + 5))
    else
        target=$((current - 5))
    fi
    [ "$target" -ge 5 ] || target=5
    [ "$target" -le 100 ] || target=100
    exec backlight "$target"
elif command -v brightnessctl >/dev/null 2>&1; then
    if [ "$direction" = up ]; then
        exec brightnessctl -e4 -n2 set 5%+
    else
        exec brightnessctl -e4 -n2 set 5%-
    fi
else
    printf 'No supported backlight control was found.\n' >&2
    exit 1
fi
