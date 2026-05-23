#!/bin/sh

set -eu

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
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

if [ -z "$battery_info" ]; then
    printf '{"text":"BAT ?","tooltip":"Battery information unavailable","class":"unknown"}\n'
    exit 0
fi

state="$(
    printf '%s\n' "$battery_info" |
    awk -F: 'tolower($1) ~ /state/ {sub(/^[[:space:]]+/, "", $2); print tolower($2); exit}'
)"

capacity="$(
    printf '%s\n' "$battery_info" |
    awk -F: 'tolower($1) ~ /remaining capacity/ {sub(/^[[:space:]]+/, "", $2); sub(/%.*/, "", $2); print $2; exit}'
)"

time_left="$(
    printf '%s\n' "$battery_info" |
    awk -F: 'tolower($1) ~ /remaining time/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}'
)"

capacity="$(trim "${capacity:-}")"
state="$(trim "${state:-unknown}")"
time_left="$(trim "${time_left:-unknown}")"

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
        if [ "$capacity" -le 15 ]; then
            class="$class critical"
        elif [ "$capacity" -le 30 ]; then
            class="$class warning"
        fi
        ;;
esac

if [ -n "$time_left" ] && [ "$time_left" != "unknown" ]; then
    tooltip="$tooltip | Remaining: $time_left"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(escape_json "$text")" \
    "$(escape_json "$tooltip")" \
    "$(escape_json "$class")"
