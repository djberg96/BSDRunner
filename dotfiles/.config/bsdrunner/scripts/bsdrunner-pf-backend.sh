#!/bin/sh

set -eu

action="${1:-snapshot}"
profile_dir="${HOME}/.config/bsdrunner/pf"
profile_file="$profile_dir/profile.conf"
profile_script="${HOME}/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh"
state_file="$profile_dir/last-result.conf"
applied_state_file="$profile_dir/applied-profile.conf"
managed_marker="bsdrunner_pf_profile_version=1"

allow_outbound="yes"
block_unsolicited="yes"
allow_diagnostics="yes"
allow_ipv6="yes"
allow_dhcp="yes"
allow_mdns="yes"
allow_ssh_lan="no"
allow_ssh_tarpit="no"
log_blocked="no"
ssh_tarpit_port="22"
ssh_real_port="22222"
sshd_config_file="/etc/ssh/sshd_config"

json_escape() {
    awk '
        BEGIN { first = 1 }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\r/, "")
            if (!first)
                printf "\\n"
            printf "%s", $0
            first = 0
        }
    '
}

bool_json() {
    case "$1" in
        yes|YES|true|TRUE|1|on|ON)
            printf 'true'
            ;;
        *)
            printf 'false'
            ;;
    esac
}

normalize_bool() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1|yes|true|on|enabled)
            printf 'yes\n'
            ;;
        *)
            printf 'no\n'
            ;;
    esac
}

load_profile() {
    [ -f "$profile_file" ] || return 0

    while IFS='=' read -r key value; do
        case "$key" in
            ''|\#*)
                continue
                ;;
            allow_outbound)
                allow_outbound="$(normalize_bool "$value")"
                ;;
            block_unsolicited)
                block_unsolicited="$(normalize_bool "$value")"
                ;;
            allow_diagnostics)
                allow_diagnostics="$(normalize_bool "$value")"
                ;;
            allow_ipv6)
                allow_ipv6="$(normalize_bool "$value")"
                ;;
            allow_dhcp)
                allow_dhcp="$(normalize_bool "$value")"
                ;;
            allow_mdns)
                allow_mdns="$(normalize_bool "$value")"
                ;;
            allow_ssh_lan)
                allow_ssh_lan="$(normalize_bool "$value")"
                ;;
            allow_ssh_tarpit)
                allow_ssh_tarpit="$(normalize_bool "$value")"
                ;;
            log_blocked)
                log_blocked="$(normalize_bool "$value")"
                ;;
        esac
    done <"$profile_file"

    if [ "$allow_ssh_lan" != "yes" ]; then
        allow_ssh_tarpit="no"
    fi
}

write_profile() {
    mkdir -p "$profile_dir"
    {
        printf 'allow_outbound=%s\n' "$allow_outbound"
        printf 'block_unsolicited=%s\n' "$block_unsolicited"
        printf 'allow_diagnostics=%s\n' "$allow_diagnostics"
        printf 'allow_ipv6=%s\n' "$allow_ipv6"
        printf 'allow_dhcp=%s\n' "$allow_dhcp"
        printf 'allow_mdns=%s\n' "$allow_mdns"
        printf 'allow_ssh_lan=%s\n' "$allow_ssh_lan"
        printf 'allow_ssh_tarpit=%s\n' "$allow_ssh_tarpit"
        printf 'log_blocked=%s\n' "$log_blocked"
    } >"$profile_file"
}

emit_settings() {
    printf 'allow_outbound=%s\n' "$allow_outbound"
    printf 'block_unsolicited=%s\n' "$block_unsolicited"
    printf 'allow_diagnostics=%s\n' "$allow_diagnostics"
    printf 'allow_ipv6=%s\n' "$allow_ipv6"
    printf 'allow_dhcp=%s\n' "$allow_dhcp"
    printf 'allow_mdns=%s\n' "$allow_mdns"
    printf 'allow_ssh_lan=%s\n' "$allow_ssh_lan"
    printf 'allow_ssh_tarpit=%s\n' "$allow_ssh_tarpit"
    printf 'log_blocked=%s\n' "$log_blocked"
}

profile_checksum() {
    emit_settings | cksum | awk '{ printf "%s-%s\n", $1, $2 }'
}

set_setting_value() {
    key="$1"
    value="$(normalize_bool "$2")"

    case "$key" in
        allow_outbound)
            allow_outbound="$value"
            ;;
        block_unsolicited)
            block_unsolicited="$value"
            ;;
        allow_diagnostics)
            allow_diagnostics="$value"
            ;;
        allow_ipv6)
            allow_ipv6="$value"
            ;;
        allow_dhcp)
            allow_dhcp="$value"
            ;;
        allow_mdns)
            allow_mdns="$value"
            ;;
        allow_ssh_lan)
            allow_ssh_lan="$value"
            if [ "$allow_ssh_lan" != "yes" ]; then
                allow_ssh_tarpit="no"
            fi
            ;;
        allow_ssh_tarpit)
            if [ "$value" = "yes" ] && [ "$allow_ssh_lan" != "yes" ]; then
                emit_error "Enable LAN SSH before enabling the tarpit."
                exit 1
            fi
            allow_ssh_tarpit="$value"
            ;;
        log_blocked)
            log_blocked="$value"
            ;;
        *)
            emit_error "Unknown firewall setting: $key"
            exit 1
            ;;
    esac
}

run_capture() {
    "$@" 2>&1
}

run_privileged() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    else
        "$@"
    fi
}

run_privileged_capture() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@" 2>&1
    else
        "$@" 2>&1
    fi
}

pf_running_state() {
    if ! command -v pfctl >/dev/null 2>&1; then
        printf 'unavailable\n'
        return
    fi

    info="$(pfctl -s info 2>&1 || true)"
    if printf '%s\n' "$info" | grep -qi 'Status: Enabled'; then
        printf 'running\n'
    elif printf '%s\n' "$info" | grep -qi 'Status: Disabled'; then
        printf 'stopped\n'
    elif command -v service >/dev/null 2>&1 && service pf onestatus >/dev/null 2>&1; then
        printf 'running\n'
    elif printf '%s\n' "$info" | grep -qi 'Failed to open netlink'; then
        printf 'unloaded\n'
    else
        printf 'unknown\n'
    fi
}

sysrc_value() {
    name="$1"
    if command -v sysrc >/dev/null 2>&1; then
        sysrc -n "$name" 2>/dev/null || printf 'NO\n'
    else
        printf 'unknown\n'
    fi
}

service_running() {
    name="$1"
    command -v service >/dev/null 2>&1 || return 1
    service "$name" onestatus >/dev/null 2>&1
}

endlessh_installed() {
    command -v endlessh >/dev/null 2>&1 || [ -x /usr/local/bin/endlessh ]
}

sshd_effective_port() {
    if [ "$allow_ssh_lan" = "yes" ] && [ "$allow_ssh_tarpit" = "yes" ]; then
        printf '%s\n' "$ssh_real_port"
    elif command -v sshd >/dev/null 2>&1; then
        port="$(sshd -T 2>/dev/null | awk '$1 == "port" { print $2; exit }')"
        if [ -n "$port" ]; then
            printf '%s\n' "$port"
        else
            printf '22\n'
        fi
    else
        printf '22\n'
    fi
}

check_profile_prereqs() {
    if [ "$allow_ssh_tarpit" = "yes" ] && [ "$allow_ssh_lan" != "yes" ]; then
        printf 'Enable LAN SSH before enabling the tarpit.\n'
        return 1
    fi

    if [ "$allow_ssh_tarpit" = "yes" ] && ! endlessh_installed; then
        printf 'endlessh is not installed. Install security/endlessh before enabling the tarpit.\n'
        return 1
    fi

    return 0
}

applied_state_value() {
    key="$1"
    [ -f "$applied_state_file" ] || return 0
    awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$applied_state_file"
}

write_applied_state() {
    checksum="$1"
    mkdir -p "$profile_dir"
    {
        printf 'state=managed\n'
        printf 'checksum=%s\n' "$checksum"
        printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    } >"$applied_state_file"
}

installed_config_state() {
    if [ ! -f /etc/pf.conf ]; then
        printf 'missing\n'
    elif grep -q "$managed_marker" /etc/pf.conf 2>/dev/null; then
        printf 'managed\n'
    elif [ "$(applied_state_value state)" = "managed" ]; then
        printf 'managed\n'
    else
        printf 'external\n'
    fi
}

installed_config_checksum() {
    [ -f /etc/pf.conf ] || return 0
    checksum="$(awk -F '=' '/bsdrunner_pf_profile_checksum=/ { print $2; exit }' /etc/pf.conf 2>/dev/null || true)"
    if [ -n "$checksum" ]; then
        printf '%s\n' "$checksum"
    else
        applied_state_value checksum
    fi
}

render_profile_to_file() {
    target="$1"
    sh "$profile_script" "$profile_file" >"$target"
}

validate_file() {
    file_path="$1"
    if ! command -v pfctl >/dev/null 2>&1; then
        printf 'pfctl is not installed or is not in PATH.\n'
        return 127
    fi

    output="$(pfctl -vnf "$file_path" 2>&1)" && {
        printf '%s\n' "$output"
        return 0
    }

    if command -v mdo >/dev/null 2>&1; then
        privileged_output="$(mdo pfctl -vnf "$file_path" 2>&1)" && {
            printf '%s\n' "$privileged_output"
            return 0
        }

        printf '%s\n%s\n' "$output" "$privileged_output"
        return 1
    fi

    printf '%s\n' "$output"
    return 1
}

last_result_value() {
    key="$1"
    [ -f "$state_file" ] || return 0
    awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$state_file"
}

write_last_result() {
    tone="$1"
    message="$2"
    mkdir -p "$profile_dir"
    {
        printf 'tone=%s\n' "$tone"
        printf 'message=%s\n' "$message"
        printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    } >"$state_file"
}

rules_summary_json() {
    printf '['
    printf '{"id":"outbound","label":"Outbound connections","description":"Connections started by this computer are allowed.","enabled":%s}' "$(bool_json "$allow_outbound")"
    printf ',{"id":"inbound","label":"Unsolicited inbound traffic","description":"Inbound connections are blocked unless a friendly rule allows them.","enabled":%s}' "$(bool_json "$block_unsolicited")"
    printf ',{"id":"diagnostics","label":"Ping and network diagnostics","description":"Selected ICMP diagnostics are allowed.","enabled":%s}' "$(bool_json "$allow_diagnostics")"
    printf ',{"id":"ipv6","label":"IPv6 essentials","description":"Neighbor discovery and IPv6 control messages are allowed.","enabled":%s}' "$(bool_json "$allow_ipv6")"
    printf ',{"id":"dhcp","label":"DHCP address assignment","description":"DHCP and DHCPv6 replies are allowed.","enabled":%s}' "$(bool_json "$allow_dhcp")"
    printf ',{"id":"mdns","label":"Local discovery","description":"mDNS discovery for local devices is allowed.","enabled":%s}' "$(bool_json "$allow_mdns")"
    printf ',{"id":"ssh","label":"SSH from local network","description":"SSH is limited to private IPv4 LAN ranges.","enabled":%s}' "$(bool_json "$allow_ssh_lan")"
    printf ',{"id":"tarpit","label":"SSH tarpit","description":"endlessh listens on port 22 while real SSH moves to port %s.","enabled":%s}' "$ssh_real_port" "$(bool_json "$allow_ssh_tarpit")"
    printf ',{"id":"logging","label":"Blocked attempt logging","description":"Blocked packets are written to pflog.","enabled":%s}' "$(bool_json "$log_blocked")"
    printf ']'
}

emit_snapshot() {
    load_profile
    pf_state="$(pf_running_state)"
    pf_enable="$(sysrc_value pf_enable)"
    pflog_enable="$(sysrc_value pflog_enable)"
    config_state="$(installed_config_state)"
    checksum="$(installed_config_checksum)"
    current_profile_checksum="$(profile_checksum)"
    applied_timestamp="$(applied_state_value timestamp)"
    last_tone="$(last_result_value tone)"
    last_message="$(last_result_value message)"
    last_timestamp="$(last_result_value timestamp)"
    endlessh_enable="$(sysrc_value endlessh_enable)"
    sshd_enable="$(sysrc_value sshd_enable)"
    real_ssh_port="$(sshd_effective_port)"

    [ -n "$last_tone" ] || last_tone="info"
    [ -n "$last_message" ] || last_message="Loaded firewall status."

    printf '{'
    printf '"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "$last_message" | json_escape)"
    printf '"profile_name":"PF Desktop Protection",'
    printf '"pf":{"state":"%s","running":%s,"available":%s},' \
        "$(printf '%s' "$pf_state" | json_escape)" \
        "$(if [ "$pf_state" = "running" ]; then printf true; else printf false; fi)" \
        "$(if [ "$pf_state" = "unavailable" ]; then printf false; else printf true; fi)"
    printf '"boot":{"pf_enable":"%s","pflog_enable":"%s","pf_enabled":%s,"pflog_enabled":%s},' \
        "$(printf '%s' "$pf_enable" | json_escape)" \
        "$(printf '%s' "$pflog_enable" | json_escape)" \
        "$(bool_json "$pf_enable")" \
        "$(bool_json "$pflog_enable")"
    printf '"services":{"sshd_enable":"%s","sshd_enabled":%s,"sshd_running":%s,"endlessh_installed":%s,"endlessh_enable":"%s","endlessh_enabled":%s,"endlessh_running":%s,"ssh_tarpit_port":"%s","ssh_real_port":"%s"},' \
        "$(printf '%s' "$sshd_enable" | json_escape)" \
        "$(bool_json "$sshd_enable")" \
        "$(if service_running sshd; then printf true; else printf false; fi)" \
        "$(if endlessh_installed; then printf true; else printf false; fi)" \
        "$(printf '%s' "$endlessh_enable" | json_escape)" \
        "$(bool_json "$endlessh_enable")" \
        "$(if service_running endlessh; then printf true; else printf false; fi)" \
        "$(printf '%s' "$ssh_tarpit_port" | json_escape)" \
        "$(printf '%s' "$real_ssh_port" | json_escape)"
    printf '"config":{"state":"%s","managed":%s,"checksum":"%s","profile_checksum":"%s","matches_profile":%s,"applied_timestamp":"%s"},' \
        "$config_state" \
        "$(if [ "$config_state" = "managed" ]; then printf true; else printf false; fi)" \
        "$(printf '%s' "$checksum" | json_escape)" \
        "$(printf '%s' "$current_profile_checksum" | json_escape)" \
        "$(if [ "$config_state" = "managed" ] && [ "$checksum" = "$current_profile_checksum" ]; then printf true; else printf false; fi)" \
        "$(printf '%s' "$applied_timestamp" | json_escape)"
    printf '"settings":{'
    printf '"allow_outbound":%s,' "$(bool_json "$allow_outbound")"
    printf '"block_unsolicited":%s,' "$(bool_json "$block_unsolicited")"
    printf '"allow_diagnostics":%s,' "$(bool_json "$allow_diagnostics")"
    printf '"allow_ipv6":%s,' "$(bool_json "$allow_ipv6")"
    printf '"allow_dhcp":%s,' "$(bool_json "$allow_dhcp")"
    printf '"allow_mdns":%s,' "$(bool_json "$allow_mdns")"
    printf '"allow_ssh_lan":%s,' "$(bool_json "$allow_ssh_lan")"
    printf '"allow_ssh_tarpit":%s,' "$(bool_json "$allow_ssh_tarpit")"
    printf '"log_blocked":%s' "$(bool_json "$log_blocked")"
    printf '},'
    printf '"rules":'
    rules_summary_json
    printf ','
    printf '"last_result":{"tone":"%s","message":"%s","timestamp":"%s"}' \
        "$(printf '%s' "$last_tone" | json_escape)" \
        "$(printf '%s' "$last_message" | json_escape)" \
        "$(printf '%s' "$last_timestamp" | json_escape)"
    printf '}\n'
}

emit_error() {
    message="$1"
    printf '{"ok":false,"message":"%s"}\n' "$(printf '%s' "$message" | json_escape)"
}

emit_action_result() {
    ok="$1"
    message="$2"
    details="${3:-}"
    printf '{"ok":%s,"message":"%s","details":"%s"}\n' \
        "$ok" \
        "$(printf '%s' "$message" | json_escape)" \
        "$(printf '%s' "$details" | json_escape)"
}

do_preview() {
    load_profile
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-preview.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
    rendered="$tmp_dir/pf.conf"
    render_profile_to_file "$rendered"
    validation="$(validate_file "$rendered" || true)"
    valid=false
    if validate_file "$rendered" >/dev/null 2>&1; then
        valid=true
    fi

    printf '{"ok":true,"valid":%s,"pf_conf":"%s","validation":"%s"}\n' \
        "$valid" \
        "$(json_escape <"$rendered")" \
        "$(printf '%s' "$validation" | json_escape)"
}

do_logs() {
    log_file="/var/log/pflog"

    if ! command -v tcpdump >/dev/null 2>&1; then
        emit_action_result false "tcpdump is not installed or is not in PATH." ""
        exit 1
    fi

    if [ ! -e "$log_file" ]; then
        emit_action_result true "No pflog file found yet." "PF only writes log entries for rules that include log. Enable blocked-attempt logging, apply the profile, then refresh after traffic is blocked."
        return
    fi

    if command -v mdo >/dev/null 2>&1; then
        output="$(mdo tcpdump -n -e -ttt -r "$log_file" 2>&1 || true)"
    else
        output="$(tcpdump -n -e -ttt -r "$log_file" 2>&1 || true)"
    fi

    output="$(printf '%s\n' "$output" | awk '
        /^tcpdump: verbose output suppressed/ { next }
        NF { lines[++count] = $0 }
        END {
            start = count - 11
            if (start < 1)
                start = 1
            for (i = start; i <= count; i++)
                print lines[i]
        }
    ')"

    if [ -n "$output" ]; then
        emit_action_result true "Loaded recent pflog entries." "$output"
    else
        emit_action_result true "No pflog entries to show." "PF logging is quiet until a rule with log matches traffic."
    fi
}

do_follow_logs() {
    if ! command -v tcpdump >/dev/null 2>&1; then
        printf 'tcpdump is not installed or is not in PATH.\n'
        exit 127
    fi

    if command -v mdo >/dev/null 2>&1; then
        exec mdo tcpdump -l -n -e -ttt -i pflog0
    fi

    exec tcpdump -l -n -e -ttt -i pflog0
}

do_penalty_list() {
    if ! command -v pfctl >/dev/null 2>&1; then
        emit_action_result false "pfctl is not installed or is not in PATH." ""
        exit 1
    fi

    if command -v mdo >/dev/null 2>&1; then
        output="$(mdo pfctl -t ssh_abuse -T show 2>&1 || true)"
    else
        output="$(pfctl -t ssh_abuse -T show 2>&1 || true)"
    fi

    if printf '%s\n' "$output" | grep -qi 'Table does not exist'; then
        output=""
    fi

    printf '{"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "Loaded SSH penalty box." | json_escape)"
    printf '"entries":['
    first=1
    printf '%s\n' "$output" | awk '
        /^[[:space:]]*$/ { next }
        /^(No ALTQ|ALTQ)/ { next }
        {
            value = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^[0-9A-Fa-f:.]+$/)
                print value
        }
    ' | while IFS= read -r ip_address; do
        if [ "$first" -eq 0 ]; then
            printf ','
        fi
        first=0
        printf '{"ip":"%s"}' "$(printf '%s' "$ip_address" | json_escape)"
    done
    printf ']}\n'
}

do_penalty_clear() {
    ip_address="${1:-}"

    case "$ip_address" in
        ''|*[!0-9A-Fa-f:.]*)
            emit_action_result false "Select a valid penalty-box IP address first." ""
            exit 1
            ;;
    esac

    output="$(run_privileged_capture pfctl -t ssh_abuse -T delete "$ip_address")" || {
        emit_action_result false "Unable to clear $ip_address from the penalty box." "$output"
        exit 1
    }

    source_output="$(run_privileged_capture pfctl -K "$ip_address" || true)"
    state_output="$(run_privileged_capture pfctl -k "$ip_address" || true)"

    emit_action_result true "Cleared $ip_address from the penalty box." "$output
$source_output
$state_output"
}

do_penalty_clear_all() {
    entries="$(run_privileged_capture pfctl -t ssh_abuse -T show | awk '
        /^[[:space:]]*$/ { next }
        /^(No ALTQ|ALTQ)/ { next }
        {
            value = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^[0-9A-Fa-f:.]+$/)
                print value
        }
    ')"

    output="$(run_privileged_capture pfctl -t ssh_abuse -T flush)" || {
        emit_action_result false "Unable to clear the penalty box." "$output"
        exit 1
    }

    reset_output=""
    for ip_address in $entries; do
        reset_output="$reset_output
$(run_privileged_capture pfctl -K "$ip_address" || true)
$(run_privileged_capture pfctl -k "$ip_address" || true)"
    done

    emit_action_result true "Cleared all penalty-box entries." "$output
$reset_output"
}

do_validate() {
    load_profile
    write_profile

    if ! prereq_output="$(check_profile_prereqs)"; then
        write_last_result "error" "Firewall profile prerequisites are not met."
        emit_action_result false "Firewall profile prerequisites are not met." "$prereq_output"
        exit 1
    fi

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-validate.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
    rendered="$tmp_dir/pf.conf"
    render_profile_to_file "$rendered"

    if output="$(validate_file "$rendered")"; then
        write_last_result "success" "Generated firewall profile validated."
        emit_action_result true "Generated firewall profile validated." "$output"
    else
        write_last_result "error" "Generated firewall profile did not validate."
        emit_action_result false "Generated firewall profile did not validate." "$output"
        exit 1
    fi
}

install_rendered_profile() {
    rendered="$1"
    if command -v mdo >/dev/null 2>&1; then
        mdo install -m 0600 "$rendered" /etc/pf.conf
    else
        install -m 0600 "$rendered" /etc/pf.conf
    fi
}

reload_pf() {
    run_privileged service pf reload
}

write_sshd_tarpit_config() {
    mode="$1"
    tmp_file="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-sshd-config.XXXXXX")"

    awk -v mode="$mode" -v port="$ssh_real_port" '
        BEGIN {
            in_block = 0
            marker = "# BSDRunner disabled while tarpit is enabled: "
        }
        /^# BEGIN BSDRunner firewall SSH tarpit$/ {
            in_block = 1
            next
        }
        /^# END BSDRunner firewall SSH tarpit$/ {
            in_block = 0
            next
        }
        in_block {
            next
        }
        mode == "enable" {
            if ($0 ~ /^[[:space:]]*Port[[:space:]]+/) {
                print marker $0
                next
            }
            print
            next
        }
        mode == "disable" {
            if (index($0, marker) == 1) {
                print substr($0, length(marker) + 1)
                next
            }
            print
            next
        }
        {
            print
        }
        END {
            if (mode == "enable") {
                print ""
                print "# BEGIN BSDRunner firewall SSH tarpit"
                print "# Real sshd is moved away from port 22 while endlessh owns the tarpit."
                print "Port " port
                print "# END BSDRunner firewall SSH tarpit"
            }
        }
    ' "$sshd_config_file" >"$tmp_file"

    validation="$(run_privileged_capture sshd -t -f "$tmp_file")" || {
        rm -f "$tmp_file"
        printf '%s\n' "$validation"
        return 1
    }

    install_output="$(run_privileged_capture install -m 0600 "$tmp_file" "$sshd_config_file")" || {
        rm -f "$tmp_file"
        printf '%s\n' "$install_output"
        return 1
    }

    rm -f "$tmp_file"
    printf '%s\n%s\n' "$validation" "$install_output"
}

sync_endlessh_with_profile() {
    if ! command -v sysrc >/dev/null 2>&1 || ! command -v service >/dev/null 2>&1; then
        printf 'sysrc or service is unavailable; endlessh was not changed.\n'
        return 0
    fi

    if [ "$allow_ssh_lan" = "yes" ] && [ "$allow_ssh_tarpit" = "yes" ]; then
        if ! endlessh_installed; then
            printf 'endlessh is not installed.\n'
            return 1
        fi

        run_privileged sysrc endlessh_enable=YES
        run_privileged sysrc "endlessh_args=-p $ssh_tarpit_port"
        if service_running endlessh; then
            run_privileged service endlessh restart
        else
            run_privileged service endlessh start
        fi
        return
    fi

    run_privileged sysrc endlessh_enable=NO
    if service_running endlessh; then
        run_privileged service endlessh stop
    else
        printf 'endlessh was not running.\n'
    fi
}

sync_sshd_with_profile() {
    if ! command -v sysrc >/dev/null 2>&1 || ! command -v service >/dev/null 2>&1; then
        printf 'sysrc or service is unavailable; sshd_enable was not changed.\n'
        return 0
    fi

    if [ "$allow_ssh_lan" = "yes" ]; then
        if [ "$allow_ssh_tarpit" = "yes" ]; then
            write_sshd_tarpit_config enable
        else
            write_sshd_tarpit_config disable
        fi

        run_privileged sysrc sshd_enable=YES
        if service sshd onestatus >/dev/null 2>&1; then
            run_privileged service sshd restart
        else
            run_privileged service sshd start
        fi
        return
    fi

    write_sshd_tarpit_config disable
    run_privileged sysrc sshd_enable=NO
    if service sshd onestatus >/dev/null 2>&1; then
        run_privileged service sshd stop
    else
        printf 'sshd was not running.\n'
    fi
}

sync_ssh_services_with_profile() {
    sshd_output="$(sync_sshd_with_profile 2>&1)" || {
        printf '%s\n' "$sshd_output"
        return 1
    }

    endlessh_output="$(sync_endlessh_with_profile 2>&1)" || {
        printf '%s\n%s\n' "$sshd_output" "$endlessh_output"
        return 1
    }

    printf '%s\n%s\n' "$sshd_output" "$endlessh_output"
}

do_apply() {
    mode="${1:-normal}"
    load_profile
    write_profile

    if ! prereq_output="$(check_profile_prereqs)"; then
        write_last_result "error" "Firewall profile prerequisites are not met."
        emit_action_result false "Firewall profile prerequisites are not met." "$prereq_output"
        exit 1
    fi

    config_state="$(installed_config_state)"
    current_profile_checksum="$(profile_checksum)"
    installed_checksum="$(installed_config_checksum)"

    if [ "$config_state" = "external" ] && [ "$mode" != "adopt" ]; then
        emit_action_result false "External /etc/pf.conf detected." "Use Adopt BSDRunner Profile if you want the GUI to replace the existing file."
        exit 1
    fi

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-apply.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
    rendered="$tmp_dir/pf.conf"
    render_profile_to_file "$rendered"

    if ! validation="$(validate_file "$rendered")"; then
        write_last_result "error" "Generated firewall profile did not validate."
        emit_action_result false "Generated firewall profile did not validate." "$validation"
        exit 1
    fi

    if [ "$mode" != "adopt" ] && [ "$config_state" = "managed" ] && [ "$installed_checksum" = "$current_profile_checksum" ]; then
        if ! sshd_output="$(sync_ssh_services_with_profile 2>&1)"; then
            write_last_result "error" "Firewall profile is applied, but SSH services could not be synchronized."
            emit_action_result false "Firewall profile is applied, but SSH services could not be synchronized." "$validation
$sshd_output"
            exit 1
        fi
        write_applied_state "$current_profile_checksum"
        write_last_result "success" "BSDRunner firewall profile is already applied."
        emit_action_result true "BSDRunner firewall profile is already applied." "$validation
$sshd_output"
        return
    fi

    if install_output="$(install_rendered_profile "$rendered" 2>&1)" && reload_output="$(reload_pf 2>&1)" && sshd_output="$(sync_ssh_services_with_profile 2>&1)"; then
        write_applied_state "$current_profile_checksum"
        write_last_result "success" "BSDRunner firewall profile applied."
        emit_action_result true "BSDRunner firewall profile applied." "$validation
$install_output
$reload_output
$sshd_output"
    else
        write_last_result "error" "Unable to install, reload, or synchronize the firewall profile."
        emit_action_result false "Unable to install, reload, or synchronize the firewall profile." "$validation
${install_output:-}
${reload_output:-}
${sshd_output:-}"
        exit 1
    fi
}

do_enable() {
    load_profile

    if ! prereq_output="$(check_profile_prereqs)"; then
        write_last_result "error" "Firewall profile prerequisites are not met."
        emit_action_result false "Firewall profile prerequisites are not met." "$prereq_output"
        exit 1
    fi

    if command -v mdo >/dev/null 2>&1; then
        output="$(mdo sysrc pf_enable=YES 2>&1 && mdo sysrc pflog_enable=YES 2>&1 && mdo service pf start 2>&1 && mdo service pflog start 2>&1 && sync_ssh_services_with_profile 2>&1)" || {
            write_last_result "error" "Unable to enable firewall services."
            emit_action_result false "Unable to enable firewall services." "$output"
            exit 1
        }
    else
        output="$(sysrc pf_enable=YES 2>&1 && sysrc pflog_enable=YES 2>&1 && service pf start 2>&1 && service pflog start 2>&1 && sync_ssh_services_with_profile 2>&1)" || {
            write_last_result "error" "Unable to enable firewall services."
            emit_action_result false "Unable to enable firewall services." "$output"
            exit 1
        }
    fi

    write_last_result "success" "Firewall services enabled."
    emit_action_result true "Firewall services enabled." "$output"
}

do_disable() {
    if command -v mdo >/dev/null 2>&1; then
        output="$(mdo pfctl -d 2>&1)" || {
            write_last_result "error" "Unable to disable PF."
            emit_action_result false "Unable to disable PF." "$output"
            exit 1
        }
    else
        output="$(pfctl -d 2>&1)" || {
            write_last_result "error" "Unable to disable PF."
            emit_action_result false "Unable to disable PF." "$output"
            exit 1
        }
    fi

    write_last_result "warning" "PF disabled. The config file was left in place."
    emit_action_result true "PF disabled. The config file was left in place." "$output"
}

do_reload() {
    if output="$(reload_pf 2>&1)"; then
        write_last_result "success" "Firewall rules reloaded."
        emit_action_result true "Firewall rules reloaded." "$output"
    else
        write_last_result "error" "Unable to reload firewall rules."
        emit_action_result false "Unable to reload firewall rules." "$output"
        exit 1
    fi
}

case "$action" in
    snapshot)
        emit_snapshot
        ;;
    preview)
        do_preview
        ;;
    logs)
        do_logs
        ;;
    follow-logs)
        do_follow_logs
        ;;
    penalty-list)
        do_penalty_list
        ;;
    penalty-clear)
        do_penalty_clear "${2:-}"
        ;;
    penalty-clear-all)
        do_penalty_clear_all
        ;;
    validate)
        do_validate
        ;;
    apply)
        do_apply normal
        ;;
    adopt)
        do_apply adopt
        ;;
    enable)
        do_enable
        ;;
    disable)
        do_disable
        ;;
    reload)
        do_reload
        ;;
    set)
        load_profile
        set_setting_value "${2:-}" "${3:-no}"
        write_profile
        write_last_result "info" "Updated firewall profile setting."
        emit_snapshot
        ;;
    *)
        emit_error "Unknown firewall backend action: $action"
        exit 1
        ;;
esac
