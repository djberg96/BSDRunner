#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

command -v qs >/dev/null 2>&1 || exit 0

power_window_running() {
    ps ax -o stat= -o args= 2>/dev/null | awk '
        $1 !~ /^Z/ {
            $1 = ""
            if ($0 ~ /(^|[[:space:]])(qs|quickshell) -c bsdrunner-power([[:space:]]|$)/) {
                found = 1
                exit
            }
        }
        END { exit found ? 0 : 1 }
    '
}

if power_window_running; then
    exit 0
fi

if command -v daemon >/dev/null 2>&1; then
    daemon -f -o /tmp/bsdrunner-power-window.log qs -c bsdrunner-power
else
    (nohup qs -c bsdrunner-power >/tmp/bsdrunner-power-window.log 2>&1 &) >/dev/null 2>&1
fi
