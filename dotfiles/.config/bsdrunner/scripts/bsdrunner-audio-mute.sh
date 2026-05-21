#!/bin/sh

set -eu

cache_dir="$HOME/.cache/bsdrunner"

if command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
elif command -v pactl >/dev/null 2>&1; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
fi

mkdir -p "$cache_dir"
sh "$HOME/.config/bsdrunner/scripts/bsdrunner-audio-state.sh" > "$cache_dir/audio-state"
