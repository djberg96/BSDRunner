#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

action="${1:-snapshot}"
state_dir="${HOME}/.config/bsdrunner/dns"
state_file="$state_dir/last-result.conf"
public_forwarders_dir="/var/unbound/conf.d"
public_forwarders_file="$public_forwarders_dir/public-forwarders.conf"
ca_bundle_file="/usr/local/share/certs/ca-root-nss.crt"

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

sysrc_value() {
    name="$1"
    if command -v sysrc >/dev/null 2>&1; then
        sysrc -n "$name" 2>/dev/null || printf 'NO\n'
    else
        printf 'unknown\n'
    fi
}

service_state() {
    if ! command -v service >/dev/null 2>&1; then
        printf 'unavailable\n'
        return
    fi

    if service local_unbound onestatus >/dev/null 2>&1; then
        printf 'running\n'
        return
    fi

    output="$(service local_unbound onestatus 2>&1 || true)"
    if printf '%s\n' "$output" | grep -qi 'not running'; then
        printf 'stopped\n'
    elif printf '%s\n' "$output" | grep -qi 'does not exist'; then
        printf 'unavailable\n'
    else
        printf 'stopped\n'
    fi
}

resolv_nameservers() {
    [ -r /etc/resolv.conf ] || return 0
    awk '
        $1 == "nameserver" && $2 != "" {
            print $2
        }
    ' /etc/resolv.conf
}

resolv_search() {
    [ -r /etc/resolv.conf ] || return 0
    awk '
        ($1 == "search" || $1 == "domain") {
            for (i = 2; i <= NF; i++)
                printf "%s%s", (i == 2 ? "" : " "), $i
            printf "\n"
            exit
        }
    ' /etc/resolv.conf
}

local_resolver_active() {
    if resolv_nameservers | grep -Eq '^(127\.0\.0\.1|::1)$'; then
        printf 'yes\n'
    else
        printf 'no\n'
    fi
}

nameservers_json() {
    first=1
    printf '['
    resolv_nameservers | while IFS= read -r server; do
        [ -n "$server" ] || continue
        if [ "$first" -eq 0 ]; then
            printf ','
        fi
        first=0
        printf '"%s"' "$(printf '%s' "$server" | json_escape)"
    done
    printf ']'
}

forwarders_json() {
    files=""
    for file in /var/unbound/forward.conf /var/unbound/conf.d/*.conf; do
        [ -r "$file" ] || continue
        files="${files}${files:+ }${file}"
    done

    [ -n "$files" ] || {
        printf '[]'
        return
    }

    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function json_escape(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            gsub(/\t/, "\\t", value)
            gsub(/\r/, "", value)
            return value
        }

        function basename(path, parts, count) {
            count = split(path, parts, "/")
            return parts[count]
        }

        function emit_forwarder(i) {
            if (!in_forward || zone == "" || target_count == 0)
                return

            if (!first)
                printf ","
            first = 0

            printf "{\"zone\":\"%s\",\"source\":\"%s\",\"tls\":%s,\"targets\":[", json_escape(zone), json_escape(basename(source_file)), tls_upstream ? "true" : "false"
            for (i = 1; i <= target_count; i += 1) {
                if (i > 1)
                    printf ","
                printf "\"%s\"", json_escape(targets[i])
            }
            printf "]}"
        }

        BEGIN {
            printf "["
            first = 1
            in_forward = 0
        }

        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }

        /^[^[:space:]][A-Za-z_-]+:/ && $0 !~ /^[[:space:]]*forward-zone:/ {
            emit_forwarder()
            in_forward = 0
            zone = ""
            target_count = 0
            tls_upstream = 0
            next
        }

        /^[[:space:]]*forward-zone:/ {
            emit_forwarder()
            in_forward = 1
            zone = ""
            source_file = FILENAME
            delete targets
            target_count = 0
            tls_upstream = 0
            next
        }

        in_forward && /^[[:space:]]*name:/ {
            value = $0
            sub(/^[[:space:]]*name:[[:space:]]*/, "", value)
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            zone = trim(value)
            next
        }

        in_forward && /^[[:space:]]*forward-(addr|host):/ {
            value = $0
            sub(/^[[:space:]]*forward-(addr|host):[[:space:]]*/, "", value)
            target_count += 1
            targets[target_count] = trim(value)
            next
        }

        in_forward && /^[[:space:]]*forward-tls-upstream:/ {
            value = $0
            sub(/^[[:space:]]*forward-tls-upstream:[[:space:]]*/, "", value)
            value = tolower(trim(value))
            tls_upstream = value == "yes" || value == "true" || value == "1"
            next
        }

        END {
            emit_forwarder()
            printf "]"
        }
    ' $files
}

encrypted_forwarding_enabled() {
    files=""
    for file in /var/unbound/forward.conf /var/unbound/conf.d/*.conf; do
        [ -r "$file" ] || continue
        files="${files}${files:+ }${file}"
    done

    [ -n "$files" ] || {
        printf 'no\n'
        return
    }

    awk '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function finish_zone() {
            if (in_forward && zone == "." && tls_upstream)
                found = 1
        }

        BEGIN {
            in_forward = 0
            found = 0
            zone = ""
            tls_upstream = 0
        }

        /^[[:space:]]*#/ || /^[[:space:]]*$/ {
            next
        }

        /^[^[:space:]][A-Za-z_-]+:/ && $0 !~ /^[[:space:]]*forward-zone:/ {
            finish_zone()
            in_forward = 0
            zone = ""
            tls_upstream = 0
            next
        }

        /^[[:space:]]*forward-zone:/ {
            finish_zone()
            in_forward = 1
            zone = ""
            tls_upstream = 0
            next
        }

        in_forward && /^[[:space:]]*name:/ {
            value = $0
            sub(/^[[:space:]]*name:[[:space:]]*/, "", value)
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            zone = trim(value)
            next
        }

        in_forward && /^[[:space:]]*forward-tls-upstream:/ {
            value = $0
            sub(/^[[:space:]]*forward-tls-upstream:[[:space:]]*/, "", value)
            value = tolower(trim(value))
            tls_upstream = value == "yes" || value == "true" || value == "1"
            next
        }

        END {
            finish_zone()
            print found ? "yes" : "no"
        }
    ' $files
}

last_result_value() {
    key="$1"
    [ -f "$state_file" ] || return 0
    awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$state_file"
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

run_privileged() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    else
        "$@"
    fi
}

check_unbound_config() {
    if command -v local-unbound-checkconf >/dev/null 2>&1; then
        run_privileged local-unbound-checkconf
    elif command -v unbound-checkconf >/dev/null 2>&1; then
        run_privileged unbound-checkconf /var/unbound/unbound.conf
    else
        printf 'No Unbound config checker found; skipping static check.\n'
    fi
}

restart_unbound_after_config_change() {
    if [ "$(service_state)" != "running" ]; then
        printf 'local_unbound is not running; configuration will apply next start.\n'
        return 0
    fi

    run_privileged service local_unbound restart
}

write_public_forwarders_config() {
    mode="$1"
    tmp="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-public-forwarders.XXXXXX")"
    backup_file="$public_forwarders_file.bsdrunner-backup"
    had_existing=no

    if [ "$mode" = "tls" ] && [ ! -r "$ca_bundle_file" ]; then
        printf 'CA certificate bundle not found at %s. Install ca_root_nss first.\n' "$ca_bundle_file"
        rm -f "$tmp"
        return 1
    fi

    if [ -e "$public_forwarders_file" ]; then
        had_existing=yes
    fi

    if [ "$mode" = "tls" ]; then
        {
            printf '# Managed by BSDRunner DNS Cache.\n'
            printf '# Public root forwarding uses DNS-over-TLS with certificate verification.\n'
            printf 'server:\n'
            printf '    tls-cert-bundle: "%s"\n\n' "$ca_bundle_file"
            printf 'forward-zone:\n'
            printf '    name: "."\n'
            printf '    forward-tls-upstream: yes\n'
            printf '    forward-addr: 1.1.1.1@853#cloudflare-dns.com\n'
            printf '    forward-addr: 1.0.0.1@853#cloudflare-dns.com\n'
            printf '    forward-addr: 8.8.8.8@853#dns.google\n'
            printf '    forward-addr: 8.8.4.4@853#dns.google\n'
        } >"$tmp"
    else
        {
            printf '# Managed by BSDRunner DNS Cache.\n'
            printf '# Public root forwarding uses ordinary DNS.\n'
            printf 'forward-zone:\n'
            printf '    name: "."\n'
            printf '    forward-addr: 1.1.1.1\n'
            printf '    forward-addr: 8.8.8.8\n'
        } >"$tmp"
    fi

    run_privileged mkdir -p "$public_forwarders_dir"
    if [ "$had_existing" = "yes" ]; then
        run_privileged cp -p "$public_forwarders_file" "$backup_file"
        printf 'Backed up %s to %s.\n' "$public_forwarders_file" "$backup_file"
    fi

    run_privileged install -m 0644 "$tmp" "$public_forwarders_file"
    rm -f "$tmp"
    printf 'Wrote %s.\n' "$public_forwarders_file"

    if ! check_unbound_config; then
        if [ "$had_existing" = "yes" ]; then
            run_privileged cp -p "$backup_file" "$public_forwarders_file"
            printf 'Config check failed; restored previous public forwarder file.\n'
        else
            run_privileged rm -f "$public_forwarders_file"
            printf 'Config check failed; removed new public forwarder file.\n'
        fi
        return 1
    fi

    restart_unbound_after_config_change
}

emit_snapshot() {
    state="$(service_state)"
    boot_value="$(sysrc_value local_unbound_enable)"
    local_active="$(local_resolver_active)"
    encrypted_forwarding="$(encrypted_forwarding_enabled)"
    search_domain="$(resolv_search)"
    last_tone="$(last_result_value tone)"
    last_message="$(last_result_value message)"
    last_timestamp="$(last_result_value timestamp)"

    [ -n "$last_tone" ] || last_tone="info"
    [ -n "$last_message" ] || last_message="Loaded DNS cache status."

    printf '{'
    printf '"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "$last_message" | json_escape)"
    printf '"profile_name":"Local DNS Cache",'
    printf '"service":{"name":"local_unbound","state":"%s","running":%s,"available":%s},' \
        "$(printf '%s' "$state" | json_escape)" \
        "$(if [ "$state" = "running" ]; then printf true; else printf false; fi)" \
        "$(if [ "$state" = "unavailable" ]; then printf false; else printf true; fi)"
    printf '"boot":{"local_unbound_enable":"%s","enabled":%s},' \
        "$(printf '%s' "$boot_value" | json_escape)" \
        "$(bool_json "$boot_value")"
    printf '"resolver":{"local_active":%s,"encrypted_forwarding":%s,"ca_bundle":"%s","ca_bundle_available":%s,"search":"%s","nameservers":' \
        "$(bool_json "$local_active")" \
        "$(bool_json "$encrypted_forwarding")" \
        "$(printf '%s' "$ca_bundle_file" | json_escape)" \
        "$(if [ -r "$ca_bundle_file" ]; then printf true; else printf false; fi)" \
        "$(printf '%s' "$search_domain" | json_escape)"
    nameservers_json
    printf ',"forwarders":'
    forwarders_json
    printf '},'
    printf '"tools":{"drill":%s,"local_unbound_setup":%s,"local_unbound_control":%s},' \
        "$(if command -v drill >/dev/null 2>&1; then printf true; else printf false; fi)" \
        "$(if command -v local-unbound-setup >/dev/null 2>&1; then printf true; else printf false; fi)" \
        "$(if command -v local-unbound-control >/dev/null 2>&1; then printf true; else printf false; fi)"
    printf '"last_result":{"tone":"%s","message":"%s","timestamp":"%s"}' \
        "$(printf '%s' "$last_tone" | json_escape)" \
        "$(printf '%s' "$last_message" | json_escape)" \
        "$(printf '%s' "$last_timestamp" | json_escape)"
    printf '}\n'
}

do_enable() {
    if command -v local-unbound-setup >/dev/null 2>&1; then
        if output="$(run_privileged sysrc local_unbound_enable=YES 2>&1 && run_privileged local-unbound-setup 2>&1 && run_privileged service local_unbound start 2>&1)"; then
            write_last_result "success" "Local DNS cache enabled."
            emit_action_result true "Local DNS cache enabled." "$output"
        else
            write_last_result "error" "Unable to enable local DNS cache."
            emit_action_result false "Unable to enable local DNS cache." "$output"
            exit 1
        fi
        return
    fi

    if output="$(run_privileged sysrc local_unbound_enable=YES 2>&1 && run_privileged service local_unbound start 2>&1)"; then
        write_last_result "success" "Local DNS cache enabled."
        emit_action_result true "Local DNS cache enabled." "$output"
    else
        write_last_result "error" "Unable to enable local DNS cache."
        emit_action_result false "Unable to enable local DNS cache." "$output"
        exit 1
    fi
}

do_disable() {
    if output="$(run_privileged service local_unbound stop 2>&1 || true; run_privileged sysrc local_unbound_enable=NO 2>&1)"; then
        write_last_result "warning" "Local DNS cache disabled."
        emit_action_result true "Local DNS cache disabled." "$output"
    else
        write_last_result "error" "Unable to disable local DNS cache."
        emit_action_result false "Unable to disable local DNS cache." "$output"
        exit 1
    fi
}

do_restart() {
    if output="$(run_privileged service local_unbound restart 2>&1)"; then
        write_last_result "success" "Local DNS cache restarted."
        emit_action_result true "Local DNS cache restarted." "$output"
    else
        write_last_result "error" "Unable to restart local DNS cache."
        emit_action_result false "Unable to restart local DNS cache." "$output"
        exit 1
    fi
}

do_flush() {
    if command -v local-unbound-control >/dev/null 2>&1; then
        if output="$(run_privileged local-unbound-control reload 2>&1)"; then
            write_last_result "success" "DNS cache flushed."
            emit_action_result true "DNS cache flushed." "$output"
            return
        fi
    fi

    if output="$(run_privileged service local_unbound restart 2>&1)"; then
        write_last_result "success" "DNS cache restarted to flush cached lookups."
        emit_action_result true "DNS cache restarted to flush cached lookups." "$output"
    else
        write_last_result "error" "Unable to flush DNS cache."
        emit_action_result false "Unable to flush DNS cache." "$output"
        exit 1
    fi
}

do_enable_dot() {
    if output="$(write_public_forwarders_config tls 2>&1)"; then
        write_last_result "success" "Encrypted DNS forwarding enabled."
        emit_action_result true "Encrypted DNS forwarding enabled." "$output"
    else
        write_last_result "error" "Unable to enable encrypted DNS forwarding."
        emit_action_result false "Unable to enable encrypted DNS forwarding." "$output"
        exit 1
    fi
}

do_disable_dot() {
    if output="$(write_public_forwarders_config plain 2>&1)"; then
        write_last_result "warning" "Encrypted DNS forwarding disabled."
        emit_action_result true "Encrypted DNS forwarding disabled." "$output"
    else
        write_last_result "error" "Unable to disable encrypted DNS forwarding."
        emit_action_result false "Unable to disable encrypted DNS forwarding." "$output"
        exit 1
    fi
}

do_test() {
    host="${1:-freebsd.org}"
    case "$host" in
        *[!A-Za-z0-9._-]*|""|.*|*..*)
            emit_action_result false "Invalid lookup name." "Use a plain hostname such as freebsd.org."
            exit 1
            ;;
    esac

    server_arg=""
    if [ "$(service_state)" = "running" ]; then
        server_arg="@127.0.0.1"
    fi

    if command -v drill >/dev/null 2>&1; then
        if output="$(drill "$host" $server_arg 2>&1)"; then
            summary="$(printf '%s\n' "$output" | awk -v host="$host" '
                BEGIN {
                    print "Lookup: " host
                }
                /^;; ->>HEADER<</ {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^rcode:/) {
                            value = $(i + 1)
                            gsub(/,/, "", value)
                            print "Status: " value
                        }
                    }
                }
                /^[^;].*[[:space:]]IN[[:space:]](A|AAAA|CNAME)[[:space:]]/ {
                    type = ""
                    value = ""
                    for (i = 1; i <= NF; i++) {
                        if ($i == "IN" && i + 2 <= NF) {
                            type = $(i + 1)
                            value = $(i + 2)
                            break
                        }
                    }
                    if (type != "" && value != "")
                        print type ": " value
                }
                /^;; Query time:/ {
                    print "Query time: " $4 " " $5
                }
                /^;; SERVER:/ {
                    print "Server: " $3
                }
            ')"
            [ -n "$summary" ] || summary="$output"
            rcode="$(printf '%s\n' "$output" | awk '
                /^;; ->>HEADER<</ {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^rcode:/) {
                            value = $(i + 1)
                            gsub(/,/, "", value)
                            print value
                            exit
                        }
                    }
                }
            ')"
            if [ -n "$rcode" ] && [ "$rcode" != "NOERROR" ]; then
                write_last_result "error" "DNS lookup failed."
                emit_action_result false "DNS lookup failed." "$summary"
                exit 1
            fi
            write_last_result "success" "DNS lookup succeeded."
            emit_action_result true "DNS lookup succeeded." "$summary"
        else
            write_last_result "error" "DNS lookup failed."
            emit_action_result false "DNS lookup failed." "$output"
            exit 1
        fi
    elif command -v host >/dev/null 2>&1; then
        if output="$(host "$host" 2>&1)"; then
            write_last_result "success" "DNS lookup succeeded."
            emit_action_result true "DNS lookup succeeded." "$output"
        else
            write_last_result "error" "DNS lookup failed."
            emit_action_result false "DNS lookup failed." "$output"
            exit 1
        fi
    else
        emit_action_result false "No DNS lookup tool found." "Install or expose drill/host in PATH."
        exit 1
    fi
}

case "$action" in
    snapshot)
        emit_snapshot
        ;;
    enable)
        do_enable
        ;;
    disable)
        do_disable
        ;;
    restart)
        do_restart
        ;;
    flush)
        do_flush
        ;;
    enable_dot)
        do_enable_dot
        ;;
    disable_dot)
        do_disable_dot
        ;;
    test)
        do_test "${2:-freebsd.org}"
        ;;
    *)
        emit_error "Unknown DNS action: $action"
        exit 1
        ;;
esac
