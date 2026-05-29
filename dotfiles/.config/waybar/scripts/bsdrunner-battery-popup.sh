#!/bin/sh

set -eu

DEFAULT_ALERT_THRESHOLD=5
ALERT_THRESHOLD_FILE="${HOME}/.config/bsdrunner/battery-alert-threshold"
THEME_FILE="${HOME}/.config/bsdrunner/current-theme"

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

read_current_theme() {
    if [ -f "$THEME_FILE" ]; then
        theme="$(cat "$THEME_FILE" 2>/dev/null || true)"
        theme="$(trim "${theme:-}")"
        if [ -n "$theme" ]; then
            printf '%s\n' "$theme"
            return 0
        fi
    fi

    printf 'default\n'
}

theme_notify_color() {
    case "$1" in
        jinteki)
            printf 'rgb(ff6f83)\n'
            ;;
        haas-bioroid)
            printf 'rgb(8fd3ff)\n'
            ;;
        nbn)
            printf 'rgb(f3c316)\n'
            ;;
        weyland)
            printf 'rgb(5d8c45)\n'
            ;;
        *)
            printf 'rgb(8fb6d9)\n'
            ;;
    esac
}

show_message() {
    title="$1"
    body="$2"
    theme_name="$(read_current_theme)"
    notify_color="$(theme_notify_color "$theme_name")"

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl notify 1 5000 "$notify_color" "${title}\n${body}" >/dev/null 2>&1 || true
        exit 0
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body" >/dev/null 2>&1 || true
        exit 0
    fi

    exit 0
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

message="Status: $state_label\nCharge: ${capacity}%"

if formatted_time_left="$(format_time_left "$time_left")"; then
    message="${message}\nRemaining: ${formatted_time_left}"
fi

case "$capacity" in
    ''|*[!0-9]*)
        :
        ;;
    *)
        if [ "$state" = "discharging" ] && [ "$capacity" -le "$alert_threshold" ]; then
            message="${message}\nAlert: Critical low battery"
        else
            message="${message}\nAlert threshold: ${alert_threshold}%"
        fi
        ;;
esac

show_message "BSDRunner Battery" "$message"
