#!/bin/sh

set -eu

close_event_file="/tmp/bsdrunner-lid-close"
open_event_file="/tmp/bsdrunner-lid-open"
lock_log="/tmp/bsdrunner-hyprlock.log"
poll_interval=1
lock_delay=1

command -v hyprctl >/dev/null 2>&1 || exit 0

file_mtime() {
    target="$1"

    if [ ! -e "$target" ]; then
        printf '0\n'
        return 0
    fi

    stat -f '%m' "$target" 2>/dev/null && return 0
    stat -c '%Y' "$target" 2>/dev/null && return 0
    printf '0\n'
}

run_close_action() {
    if command -v hyprlock >/dev/null 2>&1; then
        if ! pgrep -x hyprlock >/dev/null 2>&1; then
            (hyprlock >>"$lock_log" 2>&1 &) >/dev/null 2>&1
            sleep "$lock_delay"
        fi
    fi

    hyprctl dispatch dpms off >/dev/null 2>&1 || true
}

run_open_action() {
    hyprctl dispatch dpms on >/dev/null 2>&1 || true
}

last_close_mtime="$(file_mtime "$close_event_file")"
last_open_mtime="$(file_mtime "$open_event_file")"

while :; do
    current_close_mtime="$(file_mtime "$close_event_file")"
    current_open_mtime="$(file_mtime "$open_event_file")"

    if [ "$current_close_mtime" -gt "$last_close_mtime" ]; then
        run_close_action
        last_close_mtime="$current_close_mtime"
    fi

    if [ "$current_open_mtime" -gt "$last_open_mtime" ]; then
        run_open_action
        last_open_mtime="$current_open_mtime"
    fi

    sleep "$poll_interval"
done
