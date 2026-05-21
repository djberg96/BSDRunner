#!/bin/sh

set -eu

volume="0"
muted="0"

if command -v pactl >/dev/null 2>&1; then
    pactl_volume="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+%$/) {
                    gsub(/%/, "", $i)
                    print $i
                    exit
                }
            }
        }
    ')"

    if [ -n "$pactl_volume" ]; then
        volume="$pactl_volume"
    fi

    case "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null || true)" in
        *yes*)
            muted="1"
            ;;
    esac
elif command -v wpctl >/dev/null 2>&1; then
    wpctl_output="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"

    case "$wpctl_output" in
        *MUTED*)
            muted="1"
            ;;
    esac

    wpctl_volume="$(printf '%s\n' "$wpctl_output" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]*\.[0-9]+$/ || $i ~ /^[0-9]+$/) {
                    printf "%d", ($i * 100) + 0.5
                    exit
                }
            }
        }
    ')"

    if [ -n "$wpctl_volume" ]; then
        volume="$wpctl_volume"
    fi
fi

printf 'volume=%s\nmuted=%s\n' "$volume" "$muted"
