#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

DEFAULT_ALERT_THRESHOLD=5
ALERT_THRESHOLD_FILE="${HOME}/.config/bsdrunner/battery-alert-threshold"

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

read_alert_threshold() {
    threshold="${BSDRUNNER_BATTERY_ALERT_THRESHOLD:-}"

    if [ -z "$threshold" ] && [ -f "$ALERT_THRESHOLD_FILE" ]; then
        threshold="$(cat "$ALERT_THRESHOLD_FILE" 2>/dev/null || true)"
    fi

    threshold="$(trim "${threshold:-}")"

    case "$threshold" in
        ''|*[!0-9]*)
            printf '%s\n' "$DEFAULT_ALERT_THRESHOLD"
            ;;
        *)
            if [ "$threshold" -lt 1 ] || [ "$threshold" -gt 100 ]; then
                printf '%s\n' "$DEFAULT_ALERT_THRESHOLD"
            else
                printf '%s\n' "$threshold"
            fi
            ;;
    esac
}

format_time_left() {
    raw_time="$(trim "${1:-}")"

    case "$raw_time" in
        ''|unknown)
            return 1
            ;;
        *:*)
            hours="${raw_time%%:*}"
            minutes="${raw_time#*:}"
            hours="$(trim "$hours")"
            minutes="$(trim "$minutes")"

            case "$hours:$minutes" in
                *[!0-9:]*|:*)
                    printf '%s\n' "$raw_time"
                    ;;
                *)
                    printf '%sh %sm\n' "$hours" "$minutes"
                    ;;
            esac
            ;;
        *)
            printf '%s\n' "$raw_time"
            ;;
    esac
}

show_message() {
    title="$1"
    body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body" >/dev/null 2>&1 || true
        exit 0
    fi

    exit 0
}

save_alert_threshold() {
    threshold="$1"

    mkdir -p "$(dirname "$ALERT_THRESHOLD_FILE")"
    printf '%s\n' "$threshold" > "$ALERT_THRESHOLD_FILE"
}

battery_info="$(acpiconf -i 0 2>/dev/null || true)"
alert_threshold="$(read_alert_threshold)"

if [ -z "$battery_info" ]; then
    show_message "BSDRunner Battery" "Battery information unavailable"
fi

state="$(
    printf '%s\n' "$battery_info" |
    awk 'tolower($0) ~ /^[[:space:]]*state[[:space:]]*:/ {
        sub(/^[^:]*:[[:space:]]*/, "", $0)
        print tolower($0)
        exit
    }'
)"

capacity="$(
    printf '%s\n' "$battery_info" |
    awk 'tolower($0) ~ /^[[:space:]]*remaining capacity[[:space:]]*:/ {
        sub(/^[^:]*:[[:space:]]*/, "", $0)
        sub(/%.*/, "", $0)
        print $0
        exit
    }'
)"

time_left="$(
    printf '%s\n' "$battery_info" |
    awk 'tolower($0) ~ /^[[:space:]]*remaining time[[:space:]]*:/ {
        sub(/^[^:]*:[[:space:]]*/, "", $0)
        print $0
        exit
    }'
)"

capacity="$(trim "${capacity:-?}")"
state="$(trim "${state:-unknown}")"
time_left="$(trim "${time_left:-unknown}")"

case "$state" in
    charging)
        state_label="Charging"
        ;;
    discharging)
        state_label="Discharging"
        ;;
    high|full)
        state_label="Full"
        ;;
    *)
        state_label="Unknown"
        ;;
esac

message="$(printf 'Status: %s\nCharge: %s%%' "$state_label" "$capacity")"

if formatted_time_left="$(format_time_left "$time_left")"; then
    message="$(printf '%s\nRemaining: %s' "$message" "$formatted_time_left")"
fi

case "$capacity" in
    ''|*[!0-9]*)
        :
        ;;
    *)
        if [ "$state" = "discharging" ] && [ "$capacity" -le "$alert_threshold" ]; then
            message="$(printf '%s\nAlert: Critical low battery' "$message")"
        else
            message="$(printf '%s\nAlert threshold: %s%%' "$message" "$alert_threshold")"
        fi
        ;;
esac

if command -v rofi >/dev/null 2>&1; then
    menu_message="$(printf '%s\nCurrent alert threshold: %s%%\n\nSelect a new threshold:' "$message" "$alert_threshold")"

    choice="$(
        printf '%s\n' \
            "3%" \
            "5%" \
            "7%" \
            "10%" \
            "15%" \
        | rofi -dmenu -i -p "Battery" -mesg "$menu_message"
    )"

    [ -n "${choice:-}" ] || exit 0

    selected_threshold="${choice%%%}"
    save_alert_threshold "$selected_threshold"

    confirmation="$(printf 'Battery alert threshold set to %s%%' "$selected_threshold")"
    show_message "BSDRunner Battery" "$confirmation"
fi

show_message "BSDRunner Battery" "$message"
