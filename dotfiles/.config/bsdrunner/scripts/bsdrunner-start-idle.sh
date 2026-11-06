#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

profile_file="${BSDRUNNER_POWER_PROFILE_FILE:-${HOME}/.config/bsdrunner/power/profile.conf}"
idle_config="${BSDRUNNER_HYPRIDLE_CONFIG:-${HOME}/.config/hypr/hypridle.conf}"
idle_log="${BSDRUNNER_HYPRIDLE_LOG:-/tmp/bsdrunner-hypridle.log}"

idle_running() {
    # FreeBSD's pgrep includes zombie processes. A stale hypridle zombie must
    # not prevent a fresh daemon from starting.
    ps ax -o stat= -o comm= 2>/dev/null | awk '
        $1 !~ /^Z/ && $2 == "hypridle" { found = 1; exit }
        END { exit found ? 0 : 1 }
    '
}

command -v hypridle >/dev/null 2>&1 || exit 0
command -v hyprlock >/dev/null 2>&1 || exit 0
[ -f "$idle_config" ] || exit 0

if [ -f "$profile_file" ] && ! grep -q '^lock_enabled=yes$' "$profile_file"; then
    exit 0
fi

idle_running && exit 0

if command -v daemon >/dev/null 2>&1; then
    # FreeBSD's daemon(8) creates a session-independent process. This keeps
    # the idle timer alive when the Quickshell settings window exits.
    daemon -f -o "$idle_log" hypridle -c "$idle_config"
else
    (nohup hypridle -c "$idle_config" >>"$idle_log" 2>&1 &) >/dev/null 2>&1
fi
