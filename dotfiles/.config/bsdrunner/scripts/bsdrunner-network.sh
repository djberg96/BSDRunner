#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

if command -v qs >/dev/null 2>&1; then
    exec qs -c bsdrunner-network
fi

if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -c bsdrunner-network
fi

exit 0
