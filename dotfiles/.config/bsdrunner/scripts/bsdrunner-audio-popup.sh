#!/bin/sh

set -eu

cache_dir="$HOME/.cache/bsdrunner"
mkdir -p "$cache_dir"

sh "$HOME/.config/bsdrunner/scripts/bsdrunner-audio-state.sh" > "$cache_dir/audio-state"

if ! command -v qs >/dev/null 2>&1; then
    exec pavucontrol
fi

pkill -f "qs -c bsdrunner-audio" 2>/dev/null || true
exec qs -c bsdrunner-audio
