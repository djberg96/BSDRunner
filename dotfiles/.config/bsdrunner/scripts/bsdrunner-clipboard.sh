#!/bin/sh
set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
if command -v qs >/dev/null 2>&1; then shell=qs
elif command -v quickshell >/dev/null 2>&1; then shell=quickshell
else printf 'Quickshell is not installed.\n' >&2; exit 1; fi
if "$shell" -c bsdrunner-clipboard ipc call clipboard close >/dev/null 2>&1; then exit 0; fi
if command -v daemon >/dev/null 2>&1; then
    daemon -f -o /tmp/bsdrunner-clipboard-window.log "$shell" -c bsdrunner-clipboard
else
    (nohup "$shell" -c bsdrunner-clipboard >>/tmp/bsdrunner-clipboard-window.log 2>&1 &) >/dev/null 2>&1
fi
