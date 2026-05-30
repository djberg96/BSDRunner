#!/bin/sh

set -eu

profile_file="${1:-${HOME}/.config/bsdrunner/pf/profile.conf}"

allow_outbound="yes"
block_unsolicited="yes"
allow_diagnostics="yes"
allow_ipv6="yes"
allow_dhcp="yes"
allow_mdns="yes"
allow_ssh_lan="no"

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
        esac
    done <"$profile_file"
}

emit_settings() {
    printf 'allow_outbound=%s\n' "$allow_outbound"
    printf 'block_unsolicited=%s\n' "$block_unsolicited"
    printf 'allow_diagnostics=%s\n' "$allow_diagnostics"
    printf 'allow_ipv6=%s\n' "$allow_ipv6"
    printf 'allow_dhcp=%s\n' "$allow_dhcp"
    printf 'allow_mdns=%s\n' "$allow_mdns"
    printf 'allow_ssh_lan=%s\n' "$allow_ssh_lan"
}

profile_checksum() {
    emit_settings | cksum | awk '{ printf "%s-%s\n", $1, $2 }'
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

    if [ "$allow_ssh_lan" = "yes" ]; then
        cat <<'EOF'
lan_hosts = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }"
EOF
    else
        cat <<'EOF'
# lan_hosts = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }"
EOF
    fi

    cat <<'EOF'

set skip on lo0
set block-policy return
set reassemble yes

EOF

    if [ "$block_unsolicited" = "yes" ]; then
        cat <<'EOF'
# Block everything unless an allow rule below says otherwise.
block all
EOF
    else
        cat <<'EOF'
# Desktop protection is relaxed: PF is not blocking unsolicited inbound traffic.
pass all keep state
EOF
    fi

    if [ "$allow_outbound" = "yes" ]; then
        cat <<'EOF'

# Allow connections started by this computer.
pass out all keep state
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

    if [ "$allow_ssh_lan" = "yes" ]; then
        cat <<'EOF'

# Allow SSH only from private IPv4 LAN ranges.
pass in quick inet proto tcp from $lan_hosts to any port 22 flags S/SA keep state
EOF
    else
        cat <<'EOF'

# Optional SSH rule, disabled by default:
# pass in quick inet proto tcp from $lan_hosts to any port 22 flags S/SA keep state
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
