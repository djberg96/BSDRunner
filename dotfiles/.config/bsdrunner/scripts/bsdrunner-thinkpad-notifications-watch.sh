#!/bin/sh
# Opt in only where the notification key is confirmed as IBM event 0x17.
set -efu
PATH="${BSDRUNNER_NOTIFICATION_WATCH_PATH:-/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}}"
case "${1:-}" in
    --events)
        while IFS= read -r event; do
            system=no subsystem=no notify=no
            for field in $event; do
                case "$field" in
                    '!system=ACPI') system=yes ;;
                    'subsystem=IBM') subsystem=yes ;;
                    'notify=0x17') notify=yes ;;
                esac
            done
            if [ "$system" = yes ] && [ "$subsystem" = yes ] && [ "$notify" = yes ]; then
                # ACPI events bypass Hyprland's ordinary locked-bind handling.
                if ps ax -o stat= -o comm= | awk '$1 !~ /^Z/ && $2 == "hyprlock" {found=1} END {exit found ? 0 : 1}'; then
                    continue
                fi
                sh "${BSDRUNNER_NOTIFICATION_LAUNCHER:-$HOME/.config/bsdrunner/scripts/bsdrunner-notifications.sh}" || true
            fi
        done
        ;;
    --watch)
        while :; do
            nc -U /var/run/devd.pipe | sh "$0" --events || true
            sleep 2
        done
        ;;
    '') exec lockf -t 0 "${TMPDIR:-/tmp}/bsdrunner-thinkpad-notifications-$(id -u).lock" sh "$0" --watch ;;
    *) exit 2 ;;
esac
