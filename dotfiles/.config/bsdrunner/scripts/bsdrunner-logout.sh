#!/bin/sh

set -u
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

log_file="/tmp/bsdrunner-logout.log"

{
    date
    echo ":: Requesting Hyprland exit"
    hyprctl dispatch 'hl.dsp.exit()'
    dispatch_status=$?
    echo ":: Hyprland exit status: $dispatch_status"

    sleep 0.5
    echo ":: Switching to ttyv0"
    vidcontrol -s 1 < /dev/ttyv0
    vt_status=$?
    echo ":: VT switch status: $vt_status"

    if [ "$dispatch_status" -ne 0 ]; then
        exit "$dispatch_status"
    fi

    exit "$vt_status"
} > "$log_file" 2>&1
