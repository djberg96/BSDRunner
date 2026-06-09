#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

profile_file="$HOME/.config/bsdrunner/profile.conf"
target_profile="auto"

if [ -f "$profile_file" ]; then
    # shellcheck disable=SC1090
    . "$profile_file"
fi

case "${target_profile:-auto}" in
    vm|server|headless)
        exit 0
        ;;
    auto)
        lid_state="$(sysctl -n hw.acpi.lid_switch_state 2>/dev/null || true)"
        if [ -z "$lid_state" ] || [ "$lid_state" = "NONE" ]; then
            exit 0
        fi
        ;;
esac

exec sh "$HOME/.config/bsdrunner/scripts/bsdrunner-lid-watch.sh"
