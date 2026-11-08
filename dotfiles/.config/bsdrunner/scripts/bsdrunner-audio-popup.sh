#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cache_dir="${BSDRUNNER_AUDIO_CACHE_DIR:-$HOME/.cache/bsdrunner}"
state_script="${BSDRUNNER_AUDIO_STATE_SCRIPT:-$script_dir/bsdrunner-audio-state.sh}"

mkdir -p "$cache_dir"
state_tmp="$(mktemp "$cache_dir/audio-state.XXXXXX")"
if sh "$state_script" > "$state_tmp"; then
    mv "$state_tmp" "$cache_dir/audio-state"
else
    rm -f "$state_tmp"
    exit 1
fi

if ! command -v qs >/dev/null 2>&1; then
    exec pavucontrol
fi

pkill -f "qs -c bsdrunner-audio" >/dev/null 2>&1 || true
exec qs -c bsdrunner-audio
