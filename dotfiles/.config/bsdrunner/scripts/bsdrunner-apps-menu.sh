#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

command -v qs >/dev/null 2>&1 || exit 0

if pgrep -f "qs -c bsdrunner-apps" >/dev/null 2>&1; then
    pkill -f "qs -c bsdrunner-apps" >/dev/null 2>&1 || true
    exit 0
fi

qs -c bsdrunner-apps >/tmp/bsdrunner-apps-menu.log 2>&1 &
