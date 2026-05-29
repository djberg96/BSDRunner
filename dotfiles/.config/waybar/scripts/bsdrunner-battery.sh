#!/bin/sh

set -eu

DEFAULT_ALERT_THRESHOLD=5
ALERT_STATE_FILE="/tmp/bsdrunner-battery-alert-${USER:-user}.state"
ALERT_THRESHOLD_FILE="${HOME}/.config/bsdrunner/battery-alert-threshold"

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

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

play_low_battery_alert() {
    if command -v canberra-gtk-play >/dev/null 2>&1; then
        (
            canberra-gtk-play -i battery-low >/dev/null 2>&1 || true
        ) &
        return 0
    fi

    if command -v notify-send >/dev/null 2>&1; then
        (
            notify-send "BSDRunner" "Battery critically low (${1}%)" >/dev/null 2>&1 || true
        ) &
        return 0
    fi

    return 1
}

update_low_battery_alert() {
    level="$1"
    current_state="$2"

    case "$level" in
        ''|*[!0-9]*)
            rm -f "$ALERT_STATE_FILE"
            return 0
            ;;
    esac

    if [ "$current_state" = "discharging" ] && [ "$level" -le "$ALERT_THRESHOLD" ]; then
        previous_state=""
        if [ -f "$ALERT_STATE_FILE" ]; then
            previous_state="$(cat "$ALERT_STATE_FILE" 2>/dev/null || true)"
        fi

        if [ "$previous_state" != "triggered" ]; then
            play_low_battery_alert "$level" || true
            printf 'triggered\n' >"$ALERT_STATE_FILE"
        fi
        return 0
    fi

    rm -f "$ALERT_STATE_FILE"
}

battery_icon() {
    level="$1"
    state="$2"

    if [ "$state" = "charging" ]; then
        case "$level" in
            ''|*[!0-9]*)
                printf ' '
                ;;
            [0-1][0-9]|[0-9])
                printf ' '
                ;;
            [2-4][0-9]|5[0-9])
                printf ' '
                ;;
            [6-8][0-9])
                printf ' '
                ;;
            *)
                printf ' '
                ;;
        esac
        return 0
    fi

    case "$level" in
        ''|*[!0-9]*)
            printf ''
            ;;
        [0-1][0-5]|[0-9])
            printf ''
            ;;
        1[6-9]|[2-3][0-9])
            printf ''
            ;;
        [4-6][0-9])
            printf ''
            ;;
        [7-8][0-9])
            printf ''
            ;;
        *)
            printf ''
            ;;
    esac
}

battery_info="$(acpiconf -i 0 2>/dev/null || true)"
ALERT_THRESHOLD="$(read_alert_threshold)"

if [ -z "$battery_info" ]; then
    printf '{"text":"BAT ?","tooltip":"Battery information unavailable","class":"unknown"}\n'
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

capacity="$(trim "${capacity:-}")"
state="$(trim "${state:-unknown}")"
time_left="$(trim "${time_left:-unknown}")"

update_low_battery_alert "$capacity" "$state"

if [ -z "$capacity" ]; then
    capacity="?"
fi

text="$(battery_icon "$capacity" "$state")"
tooltip="Battery: $capacity%"

case "$state" in
    charging)
        class="charging"
        ;;
    high|full)
        class="full"
        ;;
    discharging)
        class="discharging"
        ;;
    *)
        class="unknown"
        ;;
esac

case "$capacity" in
    ''|*[!0-9]*)
        :
        ;;
    *)
        if [ "$capacity" -le "$ALERT_THRESHOLD" ] && [ "$state" = "discharging" ]; then
            class="$class critical low-alert"
            tooltip="$tooltip | Critical low battery"
        elif [ "$capacity" -le 15 ]; then
            class="$class critical"
        elif [ "$capacity" -le 30 ]; then
            class="$class warning"
        fi
        ;;
esac

if [ -n "$time_left" ] && [ "$time_left" != "unknown" ]; then
    if formatted_time_left="$(format_time_left "$time_left")"; then
        tooltip="$tooltip | Remaining: $formatted_time_left"
    else
        tooltip="$tooltip | Remaining: $time_left"
    fi
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(escape_json "$text")" \
    "$(escape_json "$tooltip")" \
    "$(escape_json "$class")"
