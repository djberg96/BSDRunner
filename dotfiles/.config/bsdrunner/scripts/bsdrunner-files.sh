#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

quickshell_runner=""
if command -v qs >/dev/null 2>&1; then
    quickshell_runner="qs"
elif command -v quickshell >/dev/null 2>&1; then
    quickshell_runner="quickshell"
fi

if [ -z "$quickshell_runner" ]; then
    printf '%s\n' "Unable to find qs or quickshell in PATH." >&2
    exit 0
fi

if [ "${1:-}" = "--pick-directory" ]; then
    picker_result="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-folder-picker.XXXXXX")"
    trap 'rm -f "$picker_result"' EXIT HUP INT TERM
    export BSDRUNNER_FILES_PICK_MODE="directory"
    export BSDRUNNER_FILES_PICK_RESULT="$picker_result"
    export BSDRUNNER_FILES_INITIAL_PATH="${2:-$HOME}"

    picker_status=0
    "$quickshell_runner" -c bsdrunner-files 1>&2 || picker_status=$?
    if [ -s "$picker_result" ]; then
        cat "$picker_result"
    fi
    exit "$picker_status"
fi

exec "$quickshell_runner" -c bsdrunner-files
