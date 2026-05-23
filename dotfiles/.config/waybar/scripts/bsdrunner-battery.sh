#!/bin/sh

set -eu

escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
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

text="BAT $capacity%"
tooltip="State: $state"

case "$state" in
    charging)
        text="CHR $capacity%"
        class="charging"
        ;;
    high|full)
        text="BAT FULL"
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
    tooltip="$tooltip\\nRemaining: $time_left"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(escape_json "$text")" \
    "$(escape_json "$tooltip")" \
    "$(escape_json "$class")"
