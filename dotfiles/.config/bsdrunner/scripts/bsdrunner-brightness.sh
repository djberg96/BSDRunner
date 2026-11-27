#!/bin/sh
set -eu

case "${1:-}" in
    get)
        if [ "$(uname -s)" = FreeBSD ] && command -v backlight >/dev/null 2>&1; then
            exec backlight -q
        elif command -v brightnessctl >/dev/null 2>&1; then
            current=$(brightnessctl get)
            maximum=$(brightnessctl max)
            case "$current:$maximum" in *[!0-9:]*|:*|*:|*:0) exit 1 ;; esac
            [ "$maximum" -gt 0 ] || exit 1
            printf '%s\n' "$(( (current * 100 + maximum / 2) / maximum ))"
        else
            printf 'No supported backlight control was found.\n' >&2
            exit 1
        fi
        ;;
    set)
        value="${2:-}"
        case "$value" in ''|*[!0-9]*) printf 'Brightness must be a whole number.\n' >&2; exit 2 ;; esac
        [ "$value" -ge 5 ] && [ "$value" -le 100 ] || { printf 'Brightness must be between 5 and 100.\n' >&2; exit 2; }
        if [ "$(uname -s)" = FreeBSD ] && command -v backlight >/dev/null 2>&1; then
            backlight "$value" >/dev/null
        elif command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl -n2 set "${value}%" >/dev/null
        else
            printf 'No supported backlight control was found.\n' >&2
            exit 1
        fi
        ;;
    *) printf 'Usage: %s get|set [5-100]\n' "$0" >&2; exit 2 ;;
esac
