#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

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

default_iface() {
    route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
}

iface_config() {
    ifconfig "$1" 2>/dev/null || true
}

is_wireless_iface() {
    iface_config "$1" | awk '
        /IEEE 802\.11/ { found = 1 }
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "ssid") {
                    found = 1
                }
            }
        }
        END { exit found ? 0 : 1 }
    '
}

wireless_iface() {
    if [ -n "${1:-}" ] && is_wireless_iface "$1"; then
        printf '%s\n' "$1"
        return 0
    fi

    for iface_name in $(ifconfig -l 2>/dev/null); do
        if is_wireless_iface "$iface_name"; then
            printf '%s\n' "$iface_name"
            return 0
        fi
    done

    return 1
}

first_up_iface() {
    for iface in $(ifconfig -l 2>/dev/null); do
        if iface_config "$iface" | awk '/inet /{found=1} END{exit found ? 0 : 1}'; then
            printf '%s\n' "$iface"
            return 0
        fi
    done
    return 1
}

show_message() {
    title="$1"
    body="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body" >/dev/null 2>&1 || true
    fi
}

network_summary() {
    active_iface="$1"
    active_ssid="$2"
    active_ipv4="$3"

    if [ -n "$active_ssid" ]; then
        printf 'Wireless: %s (%s)' "$active_ssid" "$active_iface"
    elif [ -n "$active_ipv4" ]; then
        printf 'Interface: %s' "$active_iface"
    elif [ -n "$active_iface" ]; then
        printf 'Interface: %s' "$active_iface"
    else
        printf 'No active network interface'
    fi
}

rescan_wireless_networks() {
    scan_iface="$(wireless_iface "${1:-}" || true)"

    if [ -z "$scan_iface" ]; then
        show_message "BSDRunner Network" "No wireless interface found"
        return 1
    fi

    scan_output="$(ifconfig "$scan_iface" scan 2>&1 || true)"

    if [ -z "$scan_output" ]; then
        scan_output="Wireless scan completed on $scan_iface"
    fi

    if command -v rofi >/dev/null 2>&1; then
        printf '%s\n' "$scan_output" | rofi -dmenu -i -p "Networks ($scan_iface)" >/dev/null 2>&1 || true
    else
        show_message "BSDRunner Network" "$scan_output"
    fi
}

show_menu() {
    active_iface="$1"
    active_ssid="$2"
    active_ipv4="$3"
    launcher="${ROFI_CMD:-rofi -dmenu}"
    summary="$(network_summary "$active_iface" "$active_ssid" "$active_ipv4")"

    if ! command -v rofi >/dev/null 2>&1; then
        rescan_wireless_networks "$active_iface"
        exit 0
    fi

    choice="$(
        printf '%s\n' \
            "Rescan wireless networks" \
        | $launcher -i -p "Network" -mesg "$summary" 2>/dev/null
    )"

    case "${choice:-}" in
        "Rescan wireless networks")
            rescan_wireless_networks "$active_iface"
            ;;
    esac
}

action="${1:-status}"
case "$action" in
    status|menu)
        ;;
    *)
        action="status"
        ;;
esac

iface=""
[ -n "$iface" ] || iface="$(default_iface || true)"
[ -n "$iface" ] || iface="$(first_up_iface || true)"

if [ -z "$iface" ]; then
    if [ "$action" = "menu" ]; then
        show_menu "" "" ""
        exit 0
    fi

    printf '{"text":"󰤮","tooltip":"No active network interface","class":"disconnected"}\n'
    exit 0
fi

ifconfig_output="$(iface_config "$iface")"
ipv4="$(printf '%s\n' "$ifconfig_output" | awk '/inet /{print $2; exit}')"
status="$(printf '%s\n' "$ifconfig_output" | awk '/status:/{print $2; exit}')"
ssid="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="ssid") {print $(i+1); exit}}')"

if [ "$action" = "menu" ]; then
    show_menu "$iface" "$ssid" "$ipv4"
    exit 0
fi

if [ -n "$ssid" ]; then
    text=""
    tooltip="Wireless: $ssid ($iface)
Click to rescan wireless networks"
    [ -n "$ipv4" ] && tooltip="$tooltip
IPv4: $ipv4"
    class="wifi"
elif [ -n "$ipv4" ]; then
    text="󰈀"
    tooltip="Interface: $iface
IPv4: $ipv4"
    class="ethernet"
elif [ "$status" = "active" ]; then
    text="󰈁"
    tooltip="Interface: $iface
Link detected, no IPv4 address"
    class="linked"
else
    text="󰤮"
    tooltip="Interface: $iface
No active connection"
    class="disconnected"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(escape_json "$text")" \
    "$(escape_json "$tooltip")" \
    "$(escape_json "$class")"
