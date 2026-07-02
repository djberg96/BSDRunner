#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

action="${1:-snapshot}"
iface_arg="${2:-}"
state_dir="${HOME}/.config/bsdrunner/network"
state_file="$state_dir/last-result.conf"

json_escape() {
    awk '
        BEGIN { first = 1 }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "")
            if (!first)
                printf "\\n"
            printf "%s", $0
            first = 0
        }
    '
}

json_string() {
    printf '"%s"' "$(printf '%s' "${1:-}" | json_escape)"
}

run_privileged() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    else
        "$@"
    fi
}

write_last_result() {
    tone="$1"
    message="$2"
    mkdir -p "$state_dir"
    {
        printf 'tone=%s\n' "$tone"
        printf 'message=%s\n' "$message"
        printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    } >"$state_file"
}

last_result_value() {
    key="$1"
    [ -f "$state_file" ] || return 0
    awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$state_file"
}

emit_action_result() {
    ok="$1"
    message="$2"
    details="${3:-}"
    printf '{"ok":%s,"message":%s,"details":%s}\n' \
        "$ok" \
        "$(json_string "$message")" \
        "$(json_string "$details")"
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
    for iface_name in $(ifconfig -l 2>/dev/null); do
        if iface_config "$iface_name" | awk '/inet /{found=1} END{exit found ? 0 : 1}'; then
            printf '%s\n' "$iface_name"
            return 0
        fi
    done
    return 1
}

active_iface() {
    [ -n "$iface_arg" ] && {
        printf '%s\n' "$iface_arg"
        return
    }
    default_iface || wireless_iface || first_up_iface || true
}

json_bool() {
    if "$@" >/dev/null 2>&1; then
        printf 'true'
    else
        printf 'false'
    fi
}

emit_scan_json() {
    scan_iface="$1"

    if [ -z "$scan_iface" ]; then
        printf '[]'
        return
    fi

    ifconfig "$scan_iface" list scan 2>/dev/null |
    awk '
        BEGIN { first = 1 }

        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }

        NR == 1 { next }
        {
            bssid_index = 0
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^([[:xdigit:]][[:xdigit:]]:){5}[[:xdigit:]][[:xdigit:]]$/) {
                    bssid_index = i
                    break
                }
            }
            if (bssid_index == 0)
                next

            ssid = ""
            for (i = 1; i < bssid_index; i++)
                ssid = ssid (ssid == "" ? "" : " ") $i
            if (ssid == "")
                ssid = "(hidden)"

            bssid = $bssid_index
            channel = $(bssid_index + 1)
            rate = $(bssid_index + 2)
            signal_noise = $(bssid_index + 3)
            split(signal_noise, sn, ":")
            signal = sn[1]
            noise = sn[2]
            caps = ""
            for (i = bssid_index + 6; i <= NF; i++)
                caps = caps (caps == "" ? "" : " ") $i

            if (first)
                first = 0
            else
                printf ","
            printf "{\"ssid\":\"%s\",\"bssid\":\"%s\",\"channel\":\"%s\",\"rate\":\"%s\",\"signal\":\"%s\",\"noise\":\"%s\",\"caps\":\"%s\"}", esc(ssid), esc(bssid), esc(channel), esc(rate), esc(signal), esc(noise), esc(caps)
        }
        END { }
    ' |
    awk 'BEGIN { printf "[" } { printf "%s", $0 } END { printf "]" }'
}

emit_log_json() {
    if [ ! -r /var/log/messages ]; then
        printf '[]'
        return
    fi

    tail -n 240 /var/log/messages 2>/dev/null |
    awk '
        /wlan[0-9]|iwlwifi|wpa_supplicant|dhclient/ {
            lines[++count] = $0
            if (count > 60) {
                for (i = 2; i <= count; i++)
                    lines[i - 1] = lines[i]
                count = 60
            }
        }
        END {
            printf "["
            for (i = 1; i <= count; i++) {
                line = lines[i]
                gsub(/\\/, "\\\\", line)
                gsub(/"/, "\\\"", line)
                if (i > 1)
                    printf ","
                printf "\"%s\"", line
            }
            printf "]"
        }
    '
}

emit_snapshot() {
    iface="$(active_iface)"
    ifconfig_output=""
    [ -n "$iface" ] && ifconfig_output="$(iface_config "$iface")"

    ipv4="$(printf '%s\n' "$ifconfig_output" | awk '/inet /{print $2; exit}')"
    ipv6="$(printf '%s\n' "$ifconfig_output" | awk '/inet6 / && $2 !~ /^fe80:/{print $2; exit}')"
    status="$(printf '%s\n' "$ifconfig_output" | awk '/status:/{print $2; exit}')"
    ssid="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="ssid") {print $(i+1); exit}}')"
    bssid="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="bssid") {print $(i+1); exit}}')"
    channel="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="channel") {print $(i+1); exit}}')"
    authmode="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="authmode") {print $(i+1); exit}}')"
    parent_iface="$(printf '%s\n' "$ifconfig_output" | awk '/parent interface:/{print $3; exit}')"
    media="$(printf '%s\n' "$ifconfig_output" | awk -F ': ' '/media:/{print $2; exit}')"
    roaming="$(printf '%s\n' "$ifconfig_output" | awk '{for (i=1;i<=NF;i++) if ($i=="roaming") {print $(i+1); exit}}')"
    router="$(netstat -rn -f inet 2>/dev/null | awk '$1 == "default" { print $2; exit }')"
    route_iface="$(netstat -rn -f inet 2>/dev/null | awk '$1 == "default" { print $4; exit }')"
    last_tone="$(last_result_value tone)"
    last_message="$(last_result_value message)"
    last_timestamp="$(last_result_value timestamp)"

    printf '{'
    printf '"ok":true,'
    printf '"interface":{"name":%s,"ipv4":%s,"ipv6":%s,"status":%s,"ssid":%s,"bssid":%s,"channel":%s,"authmode":%s,"parent":%s,"media":%s,"roaming":%s},' \
        "$(json_string "$iface")" \
        "$(json_string "$ipv4")" \
        "$(json_string "$ipv6")" \
        "$(json_string "$status")" \
        "$(json_string "$ssid")" \
        "$(json_string "$bssid")" \
        "$(json_string "$channel")" \
        "$(json_string "$authmode")" \
        "$(json_string "$parent_iface")" \
        "$(json_string "$media")" \
        "$(json_string "$roaming")"
    printf '"route":{"gateway":%s,"interface":%s},' "$(json_string "$router")" "$(json_string "$route_iface")"
    printf '"tools":{"mdo":%s,"wpa_supplicant":%s,"dhclient":%s,"rofi":%s},' \
        "$(json_bool command -v mdo)" \
        "$(json_bool command -v wpa_supplicant)" \
        "$(json_bool command -v dhclient)" \
        "$(json_bool command -v rofi)"
    printf '"last_result":{"tone":%s,"message":%s,"timestamp":%s},' \
        "$(json_string "${last_tone:-info}")" \
        "$(json_string "${last_message:-No network action has run yet.}")" \
        "$(json_string "$last_timestamp")"
    printf '"scan":'
    emit_scan_json "$iface"
    printf ',"logs":'
    emit_log_json
    printf '}\n'
}

recover_network() {
    iface="$(active_iface)"

    if [ -z "$iface" ]; then
        write_last_result error "No wireless interface found."
        emit_action_result false "No wireless interface found." ""
        exit 1
    fi

    output=""
    failed=no

    append_output() {
        label="$1"
        details="$2"

        [ -n "$output" ] && output="${output}
"
        output="${output}${label}"
        [ -n "$details" ] && output="${output}
$details"
    }

    run_step() {
        label="$1"
        shift

        if step_output="$(run_privileged "$@" 2>&1)"; then
            append_output "$label" "$step_output"
        else
            failed=yes
            append_output "Failed: $label" "$step_output"
        fi
    }

    run_step "Brought $iface down" ifconfig "$iface" down
    run_step "Restarted wpa_supplicant for $iface" service wpa_supplicant restart "$iface"
    run_step "Brought $iface up" ifconfig "$iface" up
    run_step "Restarted dhclient for $iface" service dhclient restart "$iface"
    run_step "Restarted netif for $iface" service netif restart "$iface"
    run_step "Restarted routing" service routing restart

    if [ "$failed" = "yes" ]; then
        write_last_result warning "Network recovery finished with warnings."
        emit_action_result false "Network recovery finished with warnings." "$output"
        exit 1
    fi

    write_last_result success "Network recovery completed."
    emit_action_result true "Network recovery completed." "$output"
}

case "$action" in
    snapshot)
        emit_snapshot
        ;;
    recover)
        recover_network
        ;;
    *)
        emit_action_result false "Unknown network action." "$action"
        exit 1
        ;;
esac
