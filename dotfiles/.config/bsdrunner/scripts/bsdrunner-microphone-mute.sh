#!/bin/sh

set -eu

if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
elif command -v wpctl >/dev/null 2>&1; then
    exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
else
    printf 'No supported audio control tool was found.\n' >&2
    exit 1
fi
