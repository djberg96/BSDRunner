#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

lock_config="${BSDRUNNER_HYPRLOCK_CONFIG:-${HOME}/.config/hypr/hyprlock.conf}"
lock_log="${BSDRUNNER_HYPRLOCK_LOG:-/tmp/bsdrunner-hyprlock.log}"

lock_running() {
    # FreeBSD's pgrep includes zombies, which are not active lock surfaces.
    ps ax -o stat= -o comm= 2>/dev/null | awk '
        $1 !~ /^Z/ && $2 == "hyprlock" { found = 1; exit }
        END { exit found ? 0 : 1 }
    '
}

command -v hyprlock >/dev/null 2>&1 || {
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Screen lock unavailable" "Install hyprlock to lock this session."
    exit 1
}

lock_running && exit 0

exec hyprlock -c "$lock_config" >>"$lock_log" 2>&1
