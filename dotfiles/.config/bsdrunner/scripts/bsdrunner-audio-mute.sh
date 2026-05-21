#!/bin/sh

set -eu

cache_dir="$HOME/.cache/bsdrunner"
server_name=""

if command -v pactl >/dev/null 2>&1; then
    server_name="$(pactl info 2>/dev/null | awk -F': ' '/^Server Name:/{print $2; exit}')"
fi

if [ -n "$server_name" ] && printf '%s\n' "$server_name" | grep -qi 'pulseaudio'; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
elif [ -n "$server_name" ] && printf '%s\n' "$server_name" | grep -qi 'pipewire' && command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
elif command -v pactl >/dev/null 2>&1; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
elif command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
fi

mkdir -p "$cache_dir"
sh "$HOME/.config/bsdrunner/scripts/bsdrunner-audio-state.sh" > "$cache_dir/audio-state"
