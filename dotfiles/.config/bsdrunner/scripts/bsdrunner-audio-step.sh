#!/bin/sh

set -eu

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
case "${1:-}" in
    up) delta=5 ;;
    down) delta=-5 ;;
    *) printf 'Usage: %s up|down\n' "$0" >&2; exit 2 ;;
esac

volume="$(sh "$script_dir/bsdrunner-audio-state.sh" | sed -n 's/^volume=//p')"
case "$volume" in
    ''|*[!0-9]*) printf 'Unable to read the current volume.\n' >&2; exit 1 ;;
esac
volume=$((volume + delta))
[ "$volume" -ge 0 ] || volume=0
[ "$volume" -le 100 ] || volume=100
exec sh "$script_dir/bsdrunner-audio-set.sh" "$volume"
