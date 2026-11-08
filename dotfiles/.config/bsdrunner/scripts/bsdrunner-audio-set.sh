#!/bin/sh

set -eu

value="${1:-}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cache_dir="${BSDRUNNER_AUDIO_CACHE_DIR:-$HOME/.cache/bsdrunner}"
state_script="${BSDRUNNER_AUDIO_STATE_SCRIPT:-$script_dir/bsdrunner-audio-state.sh}"

case "$value" in
    ''|*[!0-9]*)
        printf 'Volume must be a whole number from 0 through 100.\n' >&2
        exit 2
        ;;
esac

if [ "$value" -gt 100 ]; then
    value=100
fi

if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    pactl set-sink-volume @DEFAULT_SINK@ "${value}%"
elif command -v wpctl >/dev/null 2>&1; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${value}%"
else
    printf 'No supported audio control tool was found.\n' >&2
    exit 1
fi

mkdir -p "$cache_dir"
sh "$state_script" > "$cache_dir/audio-state"
