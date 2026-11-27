#!/bin/sh

# Opt in only on machines where the wireless key is confirmed as event 0x05.
set -efu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
case "${1:-}" in
    --events)
        while IFS= read -r event; do
            system=no subsystem=no notify=no
            for field in $event; do
                case "$field" in
                    '!system=ACPI') system=yes ;;
                    'subsystem=IBM') subsystem=yes ;;
                    'notify=0x05') notify=yes ;;
                esac
            done
            if [ "$system" = yes ] && [ "$subsystem" = yes ] && [ "$notify" = yes ]; then
                sh "${BSDRUNNER_WIRELESS_TOGGLE_SCRIPT:-$HOME/.config/bsdrunner/scripts/bsdrunner-wireless-toggle.sh}" || true
            fi
        done
        ;;
    --watch)
        while :; do
            nc -U /var/run/devd.pipe | sh "$0" --events || true
            sleep 2
        done
        ;;
    '')
        exec lockf -t 0 "${TMPDIR:-/tmp}/bsdrunner-thinkpad-wireless-$(id -u).lock" sh "$0" --watch
        ;;
    *) exit 2 ;;
esac
