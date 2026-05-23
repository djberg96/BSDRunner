#!/bin/sh

set -eu

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

first_up_iface() {
    for iface in $(ifconfig -l 2>/dev/null); do
        if ifconfig "$iface" 2>/dev/null | awk '/inet /{found=1} END{exit found ? 0 : 1}'; then
            printf '%s\n' "$iface"
            return 0
        fi
    done
    return 1
}

iface="${1:-}"
[ -n "$iface" ] || iface="$(default_iface || true)"
[ -n "$iface" ] || iface="$(first_up_iface || true)"

if [ -z "$iface" ]; then
    printf '{"text":"󰤮","tooltip":"No active network interface","class":"disconnected"}\n'
    exit 0
fi

ifconfig_output="$(ifconfig "$iface" 2>/dev/null || true)"
ipv4="$(printf '%s\n' "$ifconfig_output" | awk '/inet /{print $2; exit}')"
status="$(printf '%s\n' "$ifconfig_output" | awk '/status:/{print $2; exit}')"
ssid="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="ssid") {print $(i+1); exit}}')"

if [ -n "$ssid" ]; then
    text=""
    tooltip="Wireless: $ssid ($iface)"
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
