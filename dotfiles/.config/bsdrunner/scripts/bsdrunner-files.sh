#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

if command -v qs >/dev/null 2>&1; then
    exec qs -c bsdrunner-files
fi

if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -c bsdrunner-files
fi

printf '%s\n' "Unable to find qs or quickshell in PATH." >&2
exit 0
