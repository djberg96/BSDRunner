#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

STATE_DIR="${HOME}/.config/bsdrunner"
FORMAT_FILE="$STATE_DIR/clock-format"
ZONEINFO_DIR="/usr/share/zoneinfo"
NOTIFICATION_TIMEOUT_MS=2000
TIMEZONE_HELPER="${HOME}/.config/bsdrunner/scripts/bsdrunner-timezone-auto.sh"

escape_json() {
    printf '%s' "$1" | awk '
        BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            if (NR > 1) {
                printf "\\n"
            }
            printf "%s", $0
        }
    '
}

show_message() {
    title="$1"
    body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -t "$NOTIFICATION_TIMEOUT_MS" "$title" "$body" >/dev/null 2>&1 || true
    fi
}

current_timezone() {
    localtime="$(readlink /etc/localtime 2>/dev/null || true)"

    case "$localtime" in
        "$ZONEINFO_DIR"/*)
            printf '%s\n' "${localtime#"$ZONEINFO_DIR"/}"
            return 0
            ;;
    esac

    if [ -f /var/db/zoneinfo ]; then
        sed -n '1p' /var/db/zoneinfo 2>/dev/null || true
        return 0
    fi

    printf 'Local time\n'
}

calendar_tooltip() {
    if command -v cal >/dev/null 2>&1; then
        cal | awk -v today="$(date '+%d')" '
            BEGIN {
                today_number = today + 0
                today_text = sprintf("%2d", today_number)
                today_markup = "<span background=\"#d7e3ea\" foreground=\"#0f1418\"><b>" today_text "</b></span>"
                highlighted = 0
            }

            NR <= 2 {
                print
                next
            }

            !highlighted {
                position = index($0, today_text)
                if (position > 0) {
                    print substr($0, 1, position - 1) today_markup substr($0, position + 2)
                    highlighted = 1
                    next
                }
            }

            {
                print
            }
        '
        return 0
    fi

    date '+%B %Y'
}

clock_format() {
    format="standard"

    if [ -f "$FORMAT_FILE" ]; then
        format="$(tr -d '\n' < "$FORMAT_FILE" 2>/dev/null || true)"
    fi

    case "$format" in
        standard|long)
            printf '%s\n' "$format"
            ;;
        *)
            printf 'standard\n'
            ;;
    esac
}

toggle_clock_format() {
    mkdir -p "$STATE_DIR"

    if [ "$(clock_format)" = "standard" ]; then
        printf 'long\n' > "$FORMAT_FILE"
        show_message "BSDRunner Clock" "Clock format set to long 12-hour display"
    else
        printf 'standard\n' > "$FORMAT_FILE"
        show_message "BSDRunner Clock" "Clock format set to compact 24-hour display"
    fi
}

timezone_label_to_name() {
    case "$1" in
        "Eastern - New York")
            printf 'America/New_York\n'
            ;;
        "Central - Chicago")
            printf 'America/Chicago\n'
            ;;
        "Mountain - Denver")
            printf 'America/Denver\n'
            ;;
        "Pacific - Los Angeles")
            printf 'America/Los_Angeles\n'
            ;;
        "Arizona - Phoenix")
            printf 'America/Phoenix\n'
            ;;
        "UTC")
            printf 'UTC\n'
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

valid_timezone_name() {
    timezone_name="$1"

    case "$timezone_name" in
        ''|/*|*..*|*//*|*[!A-Za-z0-9_+./-]*)
            return 1
            ;;
    esac

    [ -f "$ZONEINFO_DIR/$timezone_name" ]
}

set_timezone() {
    timezone_name="$1"

    if ! valid_timezone_name "$timezone_name"; then
        show_message "BSDRunner Clock" "Invalid timezone: $timezone_name"
        return 1
    fi

    exec sh "$TIMEZONE_HELPER" set "$timezone_name"
}

choose_more_timezone() {
    launcher="${ROFI_CMD:-rofi -dmenu}"

    [ -d "$ZONEINFO_DIR" ] || return 1

    find "$ZONEINFO_DIR" -type f 2>/dev/null |
        sed "s|^$ZONEINFO_DIR/||" |
        awk '
            !/^(posix|right)\// &&
            !/^(Etc\/GMT[-+]?[0-9]*|Factory|localtime|posixrules)$/ {
                print
            }
        ' |
        sort |
        $launcher -i -p "Timezone" 2>/dev/null
}

show_menu() {
    launcher="${ROFI_CMD:-rofi -dmenu}"
    timezone_name="$(current_timezone)"
    format_name="$(clock_format)"
    timezone_auto_status="$(sh "$TIMEZONE_HELPER" status 2>/dev/null || true)"

    if [ "$format_name" = "standard" ]; then
        format_label="Toggle clock format - long 12-hour"
    else
        format_label="Toggle clock format - compact 24-hour"
    fi

    if ! command -v rofi >/dev/null 2>&1; then
        show_message "BSDRunner Clock" "Install rofi to use the clock menu"
        exit 0
    fi

    choice="$(
        printf '%s\n' \
            "$format_label" \
            "Central - Chicago" \
            "Eastern - New York" \
            "Mountain - Denver" \
            "Pacific - Los Angeles" \
            "Arizona - Phoenix" \
            "UTC" \
            "More timezones..." \
            "Check timezone from network" \
            "Enable automatic timezone prompts" \
            "Enable automatic timezone changes" \
            "Disable automatic timezone checks" \
        | $launcher -i -p "Clock" -mesg "Current timezone: $timezone_name
$timezone_auto_status" 2>/dev/null
    )"

    case "${choice:-}" in
        '')
            exit 0
            ;;
        Toggle\ clock\ format*)
            toggle_clock_format
            ;;
        "More timezones...")
            selected_timezone="$(choose_more_timezone || true)"
            [ -n "${selected_timezone:-}" ] || exit 0
            set_timezone "$selected_timezone"
            ;;
        "Check timezone from network")
            exec sh "$TIMEZONE_HELPER" check yes
            ;;
        "Enable automatic timezone prompts")
            exec sh "$TIMEZONE_HELPER" enable
            ;;
        "Enable automatic timezone changes")
            exec sh "$TIMEZONE_HELPER" auto
            ;;
        "Disable automatic timezone checks")
            exec sh "$TIMEZONE_HELPER" disable
            ;;
        *)
            set_timezone "$(timezone_label_to_name "$choice")"
            ;;
    esac
}

emit_status() {
    timezone_name="$(current_timezone)"
    format_name="$(clock_format)"

    if [ "$format_name" = "long" ]; then
        text="$(date '+%A %B %d  %I:%M %p')"
        format_tooltip="Long 12-hour display"
    else
        text="$(date '+%a %Y-%m-%d %H:%M')"
        format_tooltip="Compact 24-hour display"
    fi

    calendar="$(calendar_tooltip)"
    tooltip="$(printf '%s\n\n%s\n%s\n%s\n%s' \
        "$calendar" \
        "Timezone: $timezone_name" \
        "Local: $(date '+%Y-%m-%d %H:%M:%S %Z')" \
        "UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" \
        "Click to change format or timezone")"

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "$(escape_json "$text")" \
        "$(escape_json "$tooltip")" \
        "$(escape_json "$format_tooltip" | awk '{print tolower($1)}')"
}

case "${1:-status}" in
    menu)
        show_menu
        ;;
    *)
        emit_status
        ;;
esac
