#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

DEFAULT_ALERT_THRESHOLD=5
ALERT_THRESHOLD_FILE="${HOME}/.config/bsdrunner/battery-alert-threshold"

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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

save_alert_threshold() {
    threshold="$(trim "${1:-}")"

    case "$threshold" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    if [ "$threshold" -lt 1 ] || [ "$threshold" -gt 100 ]; then
        return 1
    fi

    mkdir -p "$(dirname "$ALERT_THRESHOLD_FILE")"
    printf '%s\n' "$threshold" > "$ALERT_THRESHOLD_FILE"
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

snapshot() {
    battery_info="$(acpiconf -i 0 2>/dev/null || true)"
    alert_threshold="$(read_alert_threshold)"

    if [ -z "$battery_info" ]; then
        printf '{"ok":false,"available":false,"message":"Battery information unavailable","threshold":%s}\n' "$alert_threshold"
        exit 0
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

    state="$(trim "${state:-unknown}")"
    capacity="$(trim "${capacity:-}")"
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

    formatted_time_left=""
    if formatted_time_left="$(format_time_left "$time_left")"; then
        :
    else
        formatted_time_left=""
    fi

    critical="false"
    if [ "$state" = "discharging" ] && [ -n "$capacity" ]; then
        case "$capacity" in
            *[!0-9]*)
                :
                ;;
            *)
                if [ "$capacity" -le "$alert_threshold" ]; then
                    critical="true"
                fi
                ;;
        esac
    fi

    capacity_value="$capacity"
    if [ -z "$capacity_value" ]; then
        capacity_value="?"
    fi

    printf '{"ok":true,"available":true,"state":"%s","state_label":"%s","capacity":"%s","remaining":"%s","threshold":%s,"critical":%s}\n' \
        "$(escape_json "$state")" \
        "$(escape_json "$state_label")" \
        "$(escape_json "$capacity_value")" \
        "$(escape_json "$formatted_time_left")" \
        "$alert_threshold" \
        "$critical"
}

command_name="${1:-snapshot}"

case "$command_name" in
    snapshot)
        snapshot
        ;;
    set-threshold)
        save_alert_threshold "${2:-}" || exit 1
        ;;
    *)
        echo "Usage: sh ~/.config/bsdrunner/scripts/bsdrunner-battery-backend.sh snapshot|set-threshold VALUE" >&2
        exit 1
        ;;
esac
