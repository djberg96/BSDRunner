#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

STATE_DIR="${HOME}/.config/bsdrunner"
MODE_FILE="$STATE_DIR/timezone-auto-mode"
LAST_SUGGESTION_FILE="$STATE_DIR/timezone-auto-last-suggestion"
ZONEINFO_DIR="/usr/share/zoneinfo"
NOTIFICATION_TIMEOUT_MS=3000

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

valid_timezone_name() {
    timezone_name="$1"

    case "$timezone_name" in
        ''|/*|*..*|*//*|*[!A-Za-z0-9_+./-]*)
            return 1
            ;;
    esac

    [ -f "$ZONEINFO_DIR/$timezone_name" ]
}

auto_mode() {
    mode="disabled"

    if [ -f "$MODE_FILE" ]; then
        mode="$(tr -d '\n' < "$MODE_FILE" 2>/dev/null || true)"
    fi

    case "$mode" in
        ask|auto)
            printf '%s\n' "$mode"
            ;;
        *)
            printf 'disabled\n'
            ;;
    esac
}

set_auto_mode() {
    mode="$1"

    mkdir -p "$STATE_DIR"

    case "$mode" in
        disabled)
            rm -f "$MODE_FILE"
            show_message "BSDRunner Timezone" "Automatic timezone checks disabled"
            ;;
        ask)
            printf 'ask\n' > "$MODE_FILE"
            show_message "BSDRunner Timezone" "Automatic timezone checks enabled"
            ;;
        auto)
            printf 'auto\n' > "$MODE_FILE"
            show_message "BSDRunner Timezone" "Automatic timezone changes enabled"
            ;;
        *)
            show_message "BSDRunner Timezone" "Unknown automatic timezone mode: $mode"
            return 1
            ;;
    esac
}

fetch_url() {
    url="$1"

    if command -v fetch >/dev/null 2>&1; then
        fetch -T 5 -qo - "$url" 2>/dev/null && return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 5 "$url" 2>/dev/null && return 0
    fi

    return 1
}

detected_timezone() {
    timezone_name="$(fetch_url "https://ipapi.co/timezone" | sed -n '1p' | tr -d '\r' || true)"

    if valid_timezone_name "$timezone_name"; then
        printf '%s\n' "$timezone_name"
        return 0
    fi

    timezone_name="$(
        fetch_url "https://worldtimeapi.org/api/ip" |
            sed -n 's/.*"timezone"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
            sed -n '1p' |
            tr -d '\r' || true
    )"

    if valid_timezone_name "$timezone_name"; then
        printf '%s\n' "$timezone_name"
        return 0
    fi

    return 1
}

set_timezone() {
    timezone_name="$1"

    if ! valid_timezone_name "$timezone_name"; then
        show_message "BSDRunner Timezone" "Invalid timezone: $timezone_name"
        return 1
    fi

    if command -v mdo >/dev/null 2>&1; then
        mdo -- /usr/sbin/tzsetup -s "$timezone_name"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec /usr/sbin/tzsetup -s "$timezone_name"
    elif command -v sudo >/dev/null 2>&1; then
        sudo /usr/sbin/tzsetup -s "$timezone_name"
    else
        show_message "BSDRunner Timezone" "No privilege helper found for setting /etc/localtime"
        return 1
    fi

    show_message "BSDRunner Timezone" "Timezone set to $timezone_name"
}

prompt_for_timezone() {
    suggested_timezone="$1"
    current_timezone_name="$2"
    launcher="${ROFI_CMD:-rofi -dmenu}"

    if ! command -v rofi >/dev/null 2>&1; then
        show_message "BSDRunner Timezone" "Network suggests $suggested_timezone"
        return 0
    fi

    choice="$(
        printf '%s\n' \
            "Set timezone to $suggested_timezone" \
            "Keep $current_timezone_name" \
            "Disable automatic timezone checks" \
        | $launcher -i -p "Timezone" -mesg "Network location suggests $suggested_timezone" 2>/dev/null
    )"

    case "${choice:-}" in
        "Set timezone to $suggested_timezone")
            set_timezone "$suggested_timezone"
            ;;
        "Disable automatic timezone checks")
            set_auto_mode disabled
            ;;
    esac
}

check_timezone() {
    notify_when_same="${1:-no}"
    mode="$(auto_mode)"
    current_timezone_name="$(current_timezone)"
    suggested_timezone="$(detected_timezone || true)"

    if [ -z "$suggested_timezone" ]; then
        show_message "BSDRunner Timezone" "Could not detect timezone from the network"
        return 1
    fi

    mkdir -p "$STATE_DIR"
    printf '%s\n' "$suggested_timezone" > "$LAST_SUGGESTION_FILE"

    if [ "$suggested_timezone" = "$current_timezone_name" ]; then
        if [ "$notify_when_same" = "yes" ]; then
            show_message "BSDRunner Timezone" "Network timezone already matches $current_timezone_name"
        fi
        return 0
    fi

    case "$mode" in
        auto)
            set_timezone "$suggested_timezone"
            ;;
        ask)
            prompt_for_timezone "$suggested_timezone" "$current_timezone_name"
            ;;
        *)
            show_message "BSDRunner Timezone" "Network suggests $suggested_timezone; current is $current_timezone_name"
            ;;
    esac
}

emit_status() {
    mode="$(auto_mode)"
    current_timezone_name="$(current_timezone)"
    last_suggestion=""

    if [ -f "$LAST_SUGGESTION_FILE" ]; then
        last_suggestion="$(tr -d '\n' < "$LAST_SUGGESTION_FILE" 2>/dev/null || true)"
    fi

    printf 'Mode: %s\nCurrent: %s' "$mode" "$current_timezone_name"
    if [ -n "$last_suggestion" ]; then
        printf '\nLast network suggestion: %s' "$last_suggestion"
    fi
    printf '\n'
}

case "${1:-status}" in
    status)
        emit_status
        ;;
    enable|ask)
        set_auto_mode ask
        ;;
    auto)
        set_auto_mode auto
        ;;
    disable)
        set_auto_mode disabled
        ;;
    check)
        check_timezone "${2:-yes}"
        ;;
    startup)
        [ "$(auto_mode)" = "disabled" ] && exit 0
        sleep 8
        check_timezone no
        ;;
    set)
        [ -n "${2:-}" ] || {
            show_message "BSDRunner Timezone" "Missing timezone name"
            exit 1
        }
        set_timezone "$2"
        ;;
    *)
        printf 'Usage: %s [status|enable|auto|disable|check|startup|set TIMEZONE]\n' "$0" >&2
        exit 2
        ;;
esac
