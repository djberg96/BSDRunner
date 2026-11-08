#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cache_dir="${BSDRUNNER_AUDIO_CACHE_DIR:-$HOME/.cache/bsdrunner}"
state_script="${BSDRUNNER_AUDIO_STATE_SCRIPT:-$script_dir/bsdrunner-audio-state.sh}"

if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
elif command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
else
    printf 'No supported audio control tool was found.\n' >&2
    exit 1
fi

mkdir -p "$cache_dir"
sh "$state_script" > "$cache_dir/audio-state"
