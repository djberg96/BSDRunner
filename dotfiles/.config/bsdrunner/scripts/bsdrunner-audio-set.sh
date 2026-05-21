#!/bin/sh

set -eu

value="${1:-0}"
cache_dir="$HOME/.cache/bsdrunner"

case "$value" in
    ''|*[!0-9]*)
        value="0"
        ;;
esac

if [ "$value" -gt 100 ]; then
    value=100
fi

if command -v pactl >/dev/null 2>&1; then
    pactl set-sink-volume @DEFAULT_SINK@ "${value}%"
elif command -v wpctl >/dev/null 2>&1; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${value}%"
fi

mkdir -p "$cache_dir"
sh "$HOME/.config/bsdrunner/scripts/bsdrunner-audio-state.sh" > "$cache_dir/audio-state"
