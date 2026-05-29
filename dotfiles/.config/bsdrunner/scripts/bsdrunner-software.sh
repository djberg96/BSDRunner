#!/bin/sh

set -eu

command -v qs >/dev/null 2>&1 || exit 0

runtime_dir="${XDG_RUNTIME_DIR:-}"
if [ -z "$runtime_dir" ] || printf '%s' "$runtime_dir" | grep -q '\$'; then
    runtime_dir="/tmp/${USER}-runtime"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
    export XDG_RUNTIME_DIR="$runtime_dir"
fi

exec qs -c bsdrunner-software
