#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

command -v qs >/dev/null 2>&1 || exit 0

if pgrep -f "qs -c bsdrunner-battery" >/dev/null 2>&1; then
    exit 0
fi

qs -c bsdrunner-battery >/tmp/bsdrunner-battery-window.log 2>&1 &
