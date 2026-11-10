#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
export PATH

action="${1:-}"
runner_home="${XDG_CONFIG_HOME:-$HOME/.config}/bsdrunner"
backend_command="${BSDRUNNER_POWER_BACKEND:-$runner_home/scripts/bsdrunner-shutdown-backend.sh}"
qs_command="${BSDRUNNER_POWER_QS:-qs}"
pkill_command="${BSDRUNNER_POWER_PKILL:-pkill}"

usage() {
    printf '%s\n' "Usage: $0 reboot|shutdown" >&2
    exit 64
}

case "$action" in
    reboot)
        ;;
    shutdown)
        ;;
    *)
        usage
        ;;
esac

if [ ! -x "$backend_command" ]; then
    printf '%s\n' "BSDRunner shutdown backend is unavailable." >&2
    exit 69
fi

if ! command -v "$qs_command" >/dev/null 2>&1; then
    printf '%s\n' "Quickshell is required for safe reboot and shutdown." >&2
    exit 69
fi

# Dismiss the full-screen launcher before asking applications to close. The
# BSDRunner prompt that follows is an ordinary window, so save dialogs remain
# visible and usable.
"$pkill_command" wlogout 2>/dev/null || true
"$backend_command" begin "$action"

BSDRUNNER_POWER_ACTION="$action" exec "$qs_command" -c bsdrunner-shutdown
