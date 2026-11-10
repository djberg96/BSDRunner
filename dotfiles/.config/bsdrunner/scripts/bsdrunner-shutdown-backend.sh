#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
export PATH

operation="${1:-}"
action="${2:-}"
hyprctl_command="${BSDRUNNER_POWER_HYPRCTL:-hyprctl}"
jq_command="${BSDRUNNER_POWER_JQ:-jq}"
pgrep_command="${BSDRUNNER_POWER_PGREP:-pgrep}"
kill_command="${BSDRUNNER_POWER_KILL:-kill}"
sleep_command="${BSDRUNNER_POWER_SLEEP:-sleep}"
mdo_command="${BSDRUNNER_POWER_MDO:-mdo}"
doas_command="${BSDRUNNER_POWER_DOAS:-doas}"
shutdown_command="${BSDRUNNER_POWER_SHUTDOWN:-shutdown}"
background_grace="${BSDRUNNER_POWER_BACKGROUND_GRACE:-2}"

usage() {
    printf '%s\n' "Usage: $0 begin|snapshot|force|commit [reboot|shutdown]" >&2
    exit 64
}

validate_action() {
    case "$action" in
        reboot|shutdown) ;;
        *) usage ;;
    esac
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf '%s\n' "Required command is unavailable: $1" >&2
        exit 69
    }
}

app_clients() {
    "$hyprctl_command" -j clients | "$jq_command" -c '
        [ .[]
          | select(.mapped != false)
          | select((.address // "") != "")
          | select(((.class // "") | ascii_downcase) != "wlogout")
          | select(((.title // "") | startswith("BSDRunner — ")) | not)
          | {
                address: .address,
                pid: (.pid // 0),
                class: (.class // "Application"),
                title: (.title // "Untitled")
            }
        ]
        | unique_by(.address)
    '
}

require_command "$hyprctl_command"
require_command "$jq_command"

case "$operation" in
    begin)
        validate_action
        app_clients | "$jq_command" -r '.[].address' | while IFS= read -r address; do
            [ -n "$address" ] || continue
            "$hyprctl_command" dispatch closewindow "address:$address" >/dev/null 2>&1 || true
        done
        ;;
    snapshot)
        clients="$(app_clients)"
        printf '%s\n' "$clients" | "$jq_command" -c \
            '{ok: true, apps: ., count: length}'
        ;;
    force)
        validate_action
        app_clients | "$jq_command" -r '.[].pid | select(. > 1)' | sort -u |
            while IFS= read -r pid; do
                [ -n "$pid" ] || continue
                "$kill_command" -TERM "$pid" 2>/dev/null || true
            done
        "$sleep_command" 2
        app_clients | "$jq_command" -r '.[].pid | select(. > 1)' | sort -u |
            while IFS= read -r pid; do
                [ -n "$pid" ] || continue
                "$kill_command" -KILL "$pid" 2>/dev/null || true
            done
        ;;
    commit)
        validate_action
        case "$background_grace" in
            ''|*[!0-9]*)
                printf '%s\n' "Invalid BSDRunner background grace period." >&2
                exit 64
                ;;
        esac

        # These are session infrastructure, not interactive applications. Stop
        # them only after every real window is gone, while Hyprland can still
        # service their Wayland and portal cleanup.
        background_pattern='(^|/)(xdg-desktop-portal(-hyprland|-gtk)?|waybar|hypridle|swww-daemon)($|[[:space:]])'
        background_pids="$($pgrep_command -f "$background_pattern" 2>/dev/null || true)"
        if [ -n "$background_pids" ]; then
            set -- $background_pids
            "$kill_command" -TERM "$@" 2>/dev/null || true

            remaining=$background_grace
            while [ "$remaining" -gt 0 ] && \
                "$pgrep_command" -f "$background_pattern" >/dev/null 2>&1; do
                "$sleep_command" 1
                remaining=$((remaining - 1))
            done
        fi

        if [ "$action" = reboot ]; then
            shutdown_flag=-r
        else
            shutdown_flag=-p
        fi

        if command -v "$mdo_command" >/dev/null 2>&1; then
            exec "$mdo_command" "$shutdown_command" "$shutdown_flag" now
        elif command -v "$doas_command" >/dev/null 2>&1; then
            exec "$doas_command" -n "$shutdown_command" "$shutdown_flag" now
        fi
        exec "$shutdown_command" "$shutdown_flag" now
        ;;
    *)
        usage
        ;;
esac
