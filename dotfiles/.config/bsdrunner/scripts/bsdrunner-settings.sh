#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

config_name="bsdrunner-settings"
settings_log="/tmp/bsdrunner-settings-window.log"

settings_running() {
    ps ax -o stat= -o args= 2>/dev/null | awk '
        $1 !~ /^Z/ {
            $1 = ""
            if ($0 ~ /(^|[[:space:]])(qs|quickshell) -c bsdrunner-settings([[:space:]]|$)/) {
                found = 1
                exit
            }
        }
        END { exit found ? 0 : 1 }
    '
}

settings_running && exit 0

if command -v qs >/dev/null 2>&1; then
    quickshell_cmd="qs"
elif command -v quickshell >/dev/null 2>&1; then
    quickshell_cmd="quickshell"
else
    printf '%s\n' "Unable to find qs or quickshell in PATH." >"$settings_log"
    exit 1
fi

if command -v daemon >/dev/null 2>&1; then
    daemon -f -o "$settings_log" "$quickshell_cmd" -c "$config_name"
else
    (nohup "$quickshell_cmd" -c "$config_name" >>"$settings_log" 2>&1 &) >/dev/null 2>&1
fi
