#!/bin/sh

set -eu

profile_file="${1:-${HOME}/.config/bsdrunner/pf/profile.conf}"
policy_file="$(dirname "$profile_file")/jail-policies.conf"
forward_file="$(dirname "$profile_file")/jail-port-forwards.conf"

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
ssh_real_port_configured="no"
jail_nat="no"
jail_interface="bastille0"
jail_ext_if=""

valid_interface() {
    case "${1:-}" in
        ''|*[!A-Za-z0-9_.-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

valid_real_ssh_port() {
    case "${1:-}" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    [ "$1" -ge 22201 ] && [ "$1" -le 22299 ]
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

valid_ipv4() {
    printf '%s\n' "${1:-}" | awk -F '.' '
        NF != 4 { exit 1 }
        {
            for (i = 1; i <= 4; i++)
                if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255)
                    exit 1
        }
    '
}

emit_policies() {
    [ -f "$policy_file" ] || return 0
    while IFS='|' read -r policy_name policy_address policy_mode policy_resolver; do
        case "$policy_name" in
            ''|*[!A-Za-z0-9_.-]*)
                continue
                ;;
        esac
        valid_ipv4 "$policy_address" || continue
        valid_ipv4 "$policy_resolver" || continue
        case "$policy_mode" in
            internet-only|lan|none)
                printf '%s|%s|%s|%s\n' "$policy_name" "$policy_address" "$policy_mode" "$policy_resolver"
                ;;
        esac
    done <"$policy_file"
}

valid_port() {
    case "${1:-}" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

emit_forwards() {
    [ -f "$forward_file" ] || return 0
    while IFS='|' read -r forward_name forward_address forward_protocol forward_host_port forward_jail_port; do
        case "$forward_name" in
            ''|*[!A-Za-z0-9_.-]*)
                continue
                ;;
        esac
        valid_ipv4 "$forward_address" || continue
        case "$forward_protocol" in
            tcp|udp)
                ;;
            *)
                continue
                ;;
        esac
        valid_port "$forward_host_port" || continue
        valid_port "$forward_jail_port" || continue
        printf '%s|%s|%s|%s|%s\n' "$forward_name" "$forward_address" "$forward_protocol" "$forward_host_port" "$forward_jail_port"
    done <"$forward_file"
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
            ssh_real_port)
                if valid_real_ssh_port "$value"; then
                    ssh_real_port="$value"
                    ssh_real_port_configured="yes"
                fi
                ;;
            log_blocked)
                log_blocked="$(normalize_bool "$value")"
                ;;
            jail_nat)
                jail_nat="$(normalize_bool "$value")"
                ;;
            jail_interface)
                if valid_interface "$value"; then
                    jail_interface="$value"
                else
                    jail_interface=""
                fi
                ;;
            jail_ext_if)
                if valid_interface "$value"; then
                    jail_ext_if="$value"
                else
                    jail_ext_if=""
                fi
                ;;
        esac
    done <"$profile_file"

    if [ "$allow_ssh_lan" != "yes" ]; then
        allow_ssh_tarpit="no"
    fi
    if [ "$jail_nat" = "yes" ] && { ! valid_interface "$jail_interface" || ! valid_interface "$jail_ext_if"; }; then
        jail_nat="no"
    fi
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
    if [ "$ssh_real_port_configured" = "yes" ] && valid_real_ssh_port "$ssh_real_port"; then
        printf 'ssh_real_port=%s\n' "$ssh_real_port"
    fi
    printf 'log_blocked=%s\n' "$log_blocked"
    if [ "$jail_nat" = "yes" ]; then
        printf 'jail_nat=yes\n'
        printf 'jail_interface=%s\n' "$jail_interface"
        printf 'jail_ext_if=%s\n' "$jail_ext_if"
    fi
}

profile_checksum() {
    {
        emit_settings
        emit_policies
        emit_forwards
    } | cksum | awk '{ printf "%s-%s\n", $1, $2 }'
}

render_profile() {
    checksum="$(profile_checksum)"

    cat <<EOF
# BSDRunner managed pf profile.
# Destination: /etc/pf.conf
# bsdrunner_pf_profile_version=1
# bsdrunner_pf_profile_checksum=$checksum
#
# Generated from friendly BSDRunner Firewall settings.
# Edit through the GUI or ~/.config/bsdrunner/pf/profile.conf.

icmp_types = "{ echoreq, unreach, timex }"
icmp6_types = "{ echoreq, unreach, timex, paramprob, routersol, routeradv, neighbrsol, neighbradv, toobig }"
EOF

    if [ "$jail_nat" = "yes" ]; then
        printf 'jail_ext_if = "%s"\n' "$jail_ext_if"
        printf 'jail_if = "%s"\n' "$jail_interface"
        cat <<'EOF'
table <jails> persist
EOF
        if emit_policies | awk -F '|' '$3 == "internet-only" { found = 1 } END { exit found ? 0 : 1 }'; then
            cat <<'EOF'
private_nets = "{ 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 }"
EOF
        fi
    fi

    if [ "$allow_ssh_lan" = "yes" ]; then
        cat <<'EOF'
lan_hosts = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }"
table <ssh_abuse> persist
EOF
        if [ "$allow_ssh_tarpit" = "yes" ]; then
            printf 'ssh_tarpit_port = "%s"\n' "$ssh_tarpit_port"
            printf 'ssh_real_port = "%s"\n' "$ssh_real_port"
        fi
    else
        cat <<'EOF'
# lan_hosts = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }"
# table <ssh_abuse> persist
EOF
    fi

    if [ "$jail_nat" = "yes" ]; then
        cat <<'EOF'

set skip on lo
EOF
    else
        cat <<'EOF'

set skip on lo0
EOF
    fi

    cat <<'EOF'
set block-policy return
set reassemble yes

EOF

    if [ "$jail_nat" = "yes" ]; then
        cat <<'EOF'
# Translate traffic from running Bastille jails on the current uplink.
# Bastille adds and removes jail addresses from <jails> as jails start and stop.
nat on $jail_ext_if inet from <jails> to any -> ($jail_ext_if:0)
EOF
        emit_forwards | while IFS='|' read -r forward_name forward_address forward_protocol forward_host_port forward_jail_port; do
            printf '# Forward %s/%s on the host to Bastille jail %s.\n' "$forward_host_port" "$forward_protocol" "$forward_name"
            printf 'rdr pass on $jail_ext_if inet proto %s from any to ($jail_ext_if) port %s -> %s port %s\n' \
                "$forward_protocol" "$forward_host_port" "$forward_address" "$forward_jail_port"
        done
        cat <<'EOF'
rdr-anchor "rdr/*"

EOF
    fi

    if [ "$block_unsolicited" = "yes" ]; then
        if [ "$log_blocked" = "yes" ]; then
            cat <<'EOF'
# Block everything unless an allow rule below says otherwise.
# Log blocked packets to pflog.
block log all
EOF
        else
            cat <<'EOF'
# Block everything unless an allow rule below says otherwise.
block all
EOF
        fi
    else
        cat <<'EOF'
# Desktop protection is relaxed: PF is not blocking unsolicited inbound traffic.
pass all keep state
EOF
    fi

    if [ "$allow_outbound" = "yes" ]; then
        if [ "$jail_nat" = "yes" ]; then
            emit_policies | while IFS='|' read -r policy_name policy_address policy_mode policy_resolver; do
                printf '\n# Outbound policy for Bastille jail %s.\n' "$policy_name"
                case "$policy_mode" in
                    internet-only)
                        printf 'pass out quick on $jail_ext_if inet proto { tcp udp } from %s to %s port 53 keep state\n' "$policy_address" "$policy_resolver"
                        printf 'block return out quick on $jail_ext_if inet from %s to $private_nets\n' "$policy_address"
                        printf 'pass out quick on $jail_ext_if inet from %s to any keep state\n' "$policy_address"
                        ;;
                    lan)
                        printf 'pass out quick on $jail_ext_if inet from %s to any keep state\n' "$policy_address"
                        ;;
                    none)
                        printf 'block return out quick on $jail_ext_if inet from %s to any\n' "$policy_address"
                        ;;
                esac
            done
        fi
        cat <<'EOF'

# Allow connections started by this computer.
pass out all keep state
EOF
    fi

    if [ "$jail_nat" = "yes" ]; then
        cat <<'EOF'

# Bastille stores per-jail inbound pass rules here when port redirects are used.
anchor "bastille/*"
EOF
    fi

    if [ "$allow_diagnostics" = "yes" ]; then
        cat <<'EOF'

# Allow useful IPv4 network diagnostics.
pass in quick inet proto icmp icmp-type $icmp_types keep state
EOF
    fi

    if [ "$allow_ipv6" = "yes" ]; then
        cat <<'EOF'

# Allow essential IPv6 control and diagnostics.
pass in quick inet6 proto icmp6 icmp6-type $icmp6_types keep state
EOF
    fi

    if [ "$allow_ssh_lan" = "yes" ] && [ "$allow_ssh_tarpit" = "yes" ]; then
        cat <<'EOF'

# Tarpit suspicious SSH clients on the usual SSH port.
# Real sshd is moved to $ssh_real_port by the BSDRunner backend.
pass in quick inet proto tcp to any port $ssh_tarpit_port flags S/SA keep state

# Allow real SSH only from private IPv4 LAN ranges.
# The tarpit absorbs the noisy default port, so the real SSH limits are wider:
# fifty active SSH connections per LAN source, and four hundred new attempts per 24 hours.
block in quick inet proto tcp from <ssh_abuse> to any port $ssh_real_port
pass in quick inet proto tcp from $lan_hosts to any port $ssh_real_port flags S/SA keep state (max-src-conn 50, max-src-conn-rate 400/86400, overload <ssh_abuse> flush global)
EOF
    elif [ "$allow_ssh_lan" = "yes" ]; then
        cat <<'EOF'

# Allow SSH only from private IPv4 LAN ranges.
# PF cannot count failed SSH passwords, so this limits new connection attempts:
# five active SSH connections per LAN source, and forty new attempts per 24 hours.
block in quick inet proto tcp from <ssh_abuse> to any port 22
pass in quick inet proto tcp from $lan_hosts to any port 22 flags S/SA keep state (max-src-conn 5, max-src-conn-rate 40/86400, overload <ssh_abuse> flush global)
EOF
    else
        cat <<'EOF'

# Optional SSH rule, disabled by default:
# block in quick inet proto tcp from <ssh_abuse> to any port 22
# pass in quick inet proto tcp from $lan_hosts to any port 22 flags S/SA keep state (max-src-conn 5, max-src-conn-rate 40/86400, overload <ssh_abuse> flush global)
# Optional SSH tarpit, disabled by default:
# pass in quick inet proto tcp to any port 22 flags S/SA keep state
# block in quick inet proto tcp from <ssh_abuse> to any port 22222
# pass in quick inet proto tcp from $lan_hosts to any port 22222 flags S/SA keep state (max-src-conn 50, max-src-conn-rate 400/86400, overload <ssh_abuse> flush global)
EOF
    fi

    if [ "$allow_dhcp" = "yes" ]; then
        cat <<'EOF'

# Allow DHCP and DHCPv6 client replies.
pass in quick inet proto udp from any port 67 to any port 68 keep state
pass in quick inet6 proto udp from fe80::/10 port 547 to fe80::/10 port 546 keep state
EOF
    fi

    if [ "$allow_mdns" = "yes" ]; then
        cat <<'EOF'

# Allow local network discovery with mDNS.
pass in quick inet proto udp from any to 224.0.0.251 port 5353 keep state
pass in quick inet6 proto udp from fe80::/10 to ff02::fb port 5353 keep state
EOF
    fi
}

load_profile
render_profile
