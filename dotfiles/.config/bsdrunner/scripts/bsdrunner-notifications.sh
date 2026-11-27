#!/bin/sh
set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
if command -v qs >/dev/null 2>&1; then
    quickshell=qs
elif command -v quickshell >/dev/null 2>&1; then
    quickshell=quickshell
else
    printf 'Quickshell is not installed.\n' >&2
    exit 1
fi
if "$quickshell" -c bsdrunner-notifications ipc call notifications close >/dev/null 2>&1; then
    exit 0
fi
if command -v daemon >/dev/null 2>&1; then
    daemon -f -o /tmp/bsdrunner-notifications.log "$quickshell" -c bsdrunner-notifications
else
    (nohup "$quickshell" -c bsdrunner-notifications >>/tmp/bsdrunner-notifications.log 2>&1 &) >/dev/null 2>&1
fi
