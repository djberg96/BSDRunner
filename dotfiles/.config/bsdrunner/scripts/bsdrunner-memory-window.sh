#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

command -v qs >/dev/null 2>&1 || exit 0

if pgrep -f "qs -c bsdrunner-memory" >/dev/null 2>&1; then
    pkill -f "qs -c bsdrunner-memory" >/dev/null 2>&1 || true
    sleep 0.15
fi

qs -c bsdrunner-memory >/tmp/bsdrunner-memory-window.log 2>&1 &
