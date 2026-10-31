#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
export PATH

hyprctl_command="${BSDRUNNER_LOGOUT_HYPRCTL:-hyprctl}"

if ! command -v "$hyprctl_command" >/dev/null 2>&1; then
    printf '%s\n' "Unable to log out: hyprctl was not found." >&2
    exit 127
fi

# Ending the user compositor ends the greetd-owned session. greetd, not this
# helper, is responsible for reclaiming VT 9 and starting a fresh greeter.
exec "$hyprctl_command" dispatch 'hl.dsp.exit()'
