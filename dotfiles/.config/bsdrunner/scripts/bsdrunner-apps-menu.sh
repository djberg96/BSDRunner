#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

config_name="bsdrunner-apps"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
[ -d "$runtime_dir" ] || runtime_dir="/tmp"
pid_file="$runtime_dir/bsdrunner-apps-menu.pid"
log_file="/tmp/bsdrunner-apps-menu.log"

if [ -r "$pid_file" ]; then
    menu_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$menu_pid" ] && kill -0 "$menu_pid" 2>/dev/null; then
        kill "$menu_pid" 2>/dev/null || true
        rm -f "$pid_file"
        exit 0
    fi
    rm -f "$pid_file"
fi

if command -v qs >/dev/null 2>&1; then
    quickshell_cmd="qs"
elif command -v quickshell >/dev/null 2>&1; then
    quickshell_cmd="quickshell"
else
    printf '%s\n' "Unable to find qs or quickshell in PATH." > "$log_file"
    exit 0
fi

"$quickshell_cmd" -c "$config_name" > "$log_file" 2>&1 &
printf '%s\n' "$!" > "$pid_file"
