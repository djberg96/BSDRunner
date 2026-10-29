#!/bin/sh

set -eu

test_mode="${BSDRUNNER_JAILS_TEST_MODE:-0}"
if [ "$test_mode" = "1" ]; then
    PATH="${BSDRUNNER_JAILS_TEST_PATH:-/usr/bin:/bin}"
    etc_dir="${BSDRUNNER_JAILS_TEST_ETC_DIR:-/etc}"
    state_dir="${BSDRUNNER_JAILS_TEST_STATE_DIR:-${TMPDIR:-/tmp}/bsdrunner-jails-test-state}"
    bastille_config_file="${BSDRUNNER_JAILS_TEST_BASTILLE_CONFIG:-$etc_dir/bastille/bastille.conf}"
    bastille_test_prefix="${BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX:-$etc_dir/bastille-root}"
    pf_backend="${BSDRUNNER_JAILS_TEST_PF_BACKEND:-${HOME}/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh}"
else
    PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
    etc_dir="/etc"
    state_dir="${HOME}/.config/bsdrunner/jails"
    bastille_config_file="/usr/local/etc/bastille/bastille.conf"
    bastille_test_prefix=""
    pf_backend="${HOME}/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh"
fi
export PATH

action="${1:-snapshot}"
state_file="$state_dir/last-result.conf"
fixture_file="${BSDRUNNER_JAILS_FIXTURE:-}"

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

run_privileged() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    else
        "$@"
    fi
}

run_bastille_read() {
    if bastille "$@" 2>/dev/null; then
        return 0
    fi
    if command -v mdo >/dev/null 2>&1; then
        mdo bastille "$@" 2>/dev/null
        return $?
    fi
    return 1
}

run_bastille_list_all() {
    if output="$(run_bastille_read list all 2>/dev/null)"; then
        printf '%s\n' "$output"
        return 0
    fi
    run_bastille_read list -a 2>/dev/null
}

host_release_value() {
    if command -v freebsd-version >/dev/null 2>&1; then
        freebsd-version -u 2>/dev/null || true
    elif command -v uname >/dev/null 2>&1; then
        uname -r 2>/dev/null || true
    fi
}

bastille_prefix_value() {
    if [ "$test_mode" = "1" ]; then
        printf '%s\n' "$bastille_test_prefix"
        return
    fi
    [ -r "$bastille_config_file" ] || return 1
    awk -F '=' '
        /^[[:space:]]*bastille_prefix[[:space:]]*=/ {
            value = substr($0, index($0, "=") + 1)
            sub(/[[:space:]]*##.*$/, "", value)
            gsub(/^[[:space:]\"]+|[[:space:]\"]+$/, "", value)
            if (value ~ /^\//) print value
            exit
        }
    ' "$bastille_config_file"
}

bastille_config_value() {
    key="$1"
    [ -r "$bastille_config_file" ] || return 1
    awk -F '=' -v key="$key" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            value = substr($0, index($0, "=") + 1)
            sub(/[[:space:]]*##.*$/, "", value)
            gsub(/^[[:space:]\"]+|[[:space:]\"]+$/, "", value)
            print value
            exit
        }
    ' "$bastille_config_file"
}

bastille_storage_ready() {
    prefix="$(bastille_prefix_value 2>/dev/null || true)"
    [ -n "$prefix" ] && [ -d "$prefix" ] && [ -d "$prefix/jails" ] && [ -d "$prefix/releases" ]
}

bastille_zfs_configured() {
    configured_zfs_enabled="$(bastille_config_value bastille_zfs_enable 2>/dev/null || true)"
    configured_zfs_pool="$(bastille_config_value bastille_zfs_zpool 2>/dev/null || true)"
    configured_zfs_prefix="$(bastille_config_value bastille_zfs_prefix 2>/dev/null || true)"
    case "$configured_zfs_enabled" in
        YES|yes|Yes|Y|y)
            [ -n "$configured_zfs_pool" ] && [ -n "$configured_zfs_prefix" ]
            ;;
        *)
            return 1
            ;;
    esac
}

bastille_storage_configured() {
    bastille_storage_ready || bastille_zfs_configured
}

valid_pool() {
    case "${1:-}" in
        ""|*[!A-Za-z0-9_.-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

zfs_pool_exists() {
    target="$1"
    command -v zpool >/dev/null 2>&1 || return 1
    zpool list -H -o name 2>/dev/null | awk -v target="$target" '$1 == target { found = 1 } END { exit found ? 0 : 1 }'
}

zfs_pools_json() {
    if ! command -v zpool >/dev/null 2>&1; then
        printf '[]'
        return
    fi
    zpool list -H -o name 2>/dev/null |
    awk '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        NF > 0 {
            if (!first) printf ","
            first = 0
            printf "\"%s\"", esc($1)
        }
        END { printf "]" }
    '
}

emit_storage_snapshot() {
    prefix="$(bastille_prefix_value 2>/dev/null || true)"
    [ -n "$prefix" ] || prefix="/usr/local/bastille"
    zfs_pool="$(bastille_config_value bastille_zfs_zpool 2>/dev/null || true)"
    zfs_prefix="$(bastille_config_value bastille_zfs_prefix 2>/dev/null || true)"
    [ -n "$zfs_prefix" ] || zfs_prefix="bastille"
    configured=false
    initialized=false
    bastille_zfs_configured && configured=true
    bastille_storage_ready && initialized=true
    [ "$initialized" = true ] && configured=true

    target_dataset=""
    [ -n "$zfs_pool" ] && target_dataset="${zfs_pool}/${zfs_prefix}"

    printf '{"configured":%s,"initialized":%s,' "$configured" "$initialized"
    printf '"prefix":"%s","zfs_pool":"%s","zfs_prefix":"%s","target_dataset":"%s","pools":' \
        "$(printf '%s' "$prefix" | json_escape)" \
        "$(printf '%s' "$zfs_pool" | json_escape)" \
        "$(printf '%s' "$zfs_prefix" | json_escape)" \
        "$(printf '%s' "$target_dataset" | json_escape)"
    zfs_pools_json
    printf '}'
}

bastille_loopback_value() {
    network_loopback="$(bastille_config_value bastille_network_loopback 2>/dev/null || true)"
    [ -n "$network_loopback" ] || network_loopback="bastille0"
    printf '%s\n' "$network_loopback"
}

default_interface_value() {
    command -v route >/dev/null 2>&1 || return 1
    route -n get default 2>/dev/null | awk '$1 == "interface:" { print $2; exit }'
}

network_interface_exists() {
    network_interface_name="$1"
    command -v ifconfig >/dev/null 2>&1 || return 1
    ifconfig "$network_interface_name" >/dev/null 2>&1
}

pf_rules_capture() {
    rules_kind="$1"
    command -v pfctl >/dev/null 2>&1 || return 1
    if output="$(pfctl "$rules_kind" 2>/dev/null)"; then
        printf '%s\n' "$output"
        return 0
    fi
    if command -v mdo >/dev/null 2>&1; then
        mdo pfctl "$rules_kind" 2>/dev/null
        return $?
    fi
    return 1
}

pf_is_running() {
    command -v pfctl >/dev/null 2>&1 || return 1
    command -v grep >/dev/null 2>&1 || return 1
    pf_info="$(pfctl -s info 2>/dev/null || true)"
    if [ -z "$pf_info" ] && command -v mdo >/dev/null 2>&1; then
        pf_info="$(mdo pfctl -s info 2>/dev/null || true)"
    fi
    printf '%s\n' "$pf_info" | grep -qi 'Status:[[:space:]]*Enabled'
}

network_nat_ready() {
    command -v grep >/dev/null 2>&1 || return 1
    pf_rules_capture -sn | grep -Eq 'nat on .* from <jails> to any'
}

network_rdr_ready() {
    command -v grep >/dev/null 2>&1 || return 1
    pf_rules_capture -sn | grep -Eq 'rdr-anchor "?rdr/\*"?'
}

network_filter_anchor_ready() {
    command -v grep >/dev/null 2>&1 || return 1
    pf_rules_capture -sr | grep -Eq 'anchor "?bastille/\*"?'
}

bastille_network_ready() {
    network_loopback="$(bastille_loopback_value)"
    network_interface_exists "$network_loopback" && \
        [ -n "$(default_interface_value 2>/dev/null || true)" ] && \
        pf_is_running && network_nat_ready && network_rdr_ready && network_filter_anchor_ready
}

address_ipv4_value() {
    printf '%s\n' "$1" | awk -F '/' '{ print $1 }'
}

address_route_available() {
    proposed_address="$1"
    valid_jail_ipv4 "$proposed_address" || return 1
    proposed_ip="$(address_ipv4_value "$proposed_address")"
    command -v route >/dev/null 2>&1 || return 1
    if command -v ifconfig >/dev/null 2>&1 && ifconfig -a 2>/dev/null | awk -v target="$proposed_ip" '$1 == "inet" && $2 == target { found = 1 } END { exit found ? 0 : 1 }'; then
        return 1
    fi
    route_output="$(route -n get "$proposed_ip" 2>/dev/null || true)"
    route_destination="$(printf '%s\n' "$route_output" | awk '$1 == "destination:" { print $2; exit }')"
    route_interface="$(printf '%s\n' "$route_output" | awk '$1 == "interface:" { print $2; exit }')"
    loopback_interface="$(bastille_loopback_value)"
    [ "$route_destination" = "0.0.0.0" ] || [ "$route_destination" = "default" ] || [ "$route_interface" = "$loopback_interface" ]
}

recommended_jail_address() {
    candidate_host=20
    while [ "$candidate_host" -le 39 ]; do
        candidate_address="10.0.0.${candidate_host}/24"
        if address_route_available "$candidate_address"; then
            printf '%s\n' "$candidate_address"
            return
        fi
        candidate_host=$((candidate_host + 1))
    done
    for candidate_address in 10.17.89.20/24 172.31.255.20/24 192.168.254.20/24; do
        if address_route_available "$candidate_address"; then
            printf '%s\n' "$candidate_address"
            return
        fi
    done
}

emit_network_snapshot() {
    network_loopback="$(bastille_loopback_value)"
    network_external="$(default_interface_value 2>/dev/null || true)"
    network_loopback_ready=false
    network_pf_running=false
    network_nat=false
    network_rdr=false
    network_anchor=false
    network_ready=false
    network_interface_exists "$network_loopback" && network_loopback_ready=true
    pf_is_running && network_pf_running=true
    network_nat_ready && network_nat=true
    network_rdr_ready && network_rdr=true
    network_filter_anchor_ready && network_anchor=true
    if [ "$network_loopback_ready" = true ] && [ "$network_pf_running" = true ] && \
       [ "$network_nat" = true ] && [ "$network_rdr" = true ] && \
       [ "$network_anchor" = true ] && [ -n "$network_external" ]; then
        network_ready=true
    fi

    printf '{"ready":%s,"loopback_ready":%s,"pf_running":%s,"nat_ready":%s,"rdr_anchor_ready":%s,"filter_anchor_ready":%s,' \
        "$network_ready" "$network_loopback_ready" "$network_pf_running" "$network_nat" "$network_rdr" "$network_anchor"
    printf '"loopback_interface":"%s","external_interface":"%s","recommended_address":"%s"}' \
        "$(printf '%s' "$network_loopback" | json_escape)" \
        "$(printf '%s' "$network_external" | json_escape)" \
        "$(recommended_jail_address | json_escape)"
}

valid_name() {
    case "${1:-}" in
        ""|*[!A-Za-z0-9_.-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

valid_release() {
    case "${1:-}" in
        ""|*[!A-Za-z0-9_.-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

valid_address() {
    case "${1:-}" in
        inherit)
            return 0
            ;;
        ""|*[!A-Fa-f0-9:./]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

valid_jail_ipv4() {
    printf '%s\n' "${1:-}" | awk -F '/' '
        NF != 2 { exit 1 }
        $2 !~ /^[0-9]+$/ || $2 < 1 || $2 > 32 { exit 1 }
        {
            count = split($1, octets, ".")
            if (count != 4) exit 1
            for (i = 1; i <= 4; i += 1) {
                if (octets[i] !~ /^[0-9]+$/ || octets[i] < 0 || octets[i] > 255)
                    exit 1
            }
        }
    '
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
    printf '{"ok":%s,"message":"%s","details":"%s"}\n' \
        "$ok" \
        "$(printf '%s' "$message" | json_escape)" \
        "$(printf '%s' "$details" | json_escape)"
}

running_jails_json() {
    if ! command -v jls >/dev/null 2>&1; then
        printf '[]'
        return
    fi

    jls -n jid name host.hostname path ip4.addr ip6.addr 2>/dev/null |
    awk '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        function field(name, i, value) {
            for (i = 1; i <= NF; i += 1) {
                value = $i
                if (value ~ "^" name "=") {
                    sub("^" name "=", "", value)
                    gsub(/^"|"$/, "", value)
                    return value
                }
            }
            return ""
        }
        BEGIN { printf "["; first = 1 }
        NF > 0 {
            name = field("name")
            host = field("host.hostname")
            if (name == "")
                name = host
            if (name == "")
                name = "jid-" field("jid")
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"jid\":\"%s\",\"hostname\":\"%s\",\"path\":\"%s\",\"ipv4\":\"%s\",\"ipv6\":\"%s\",\"state\":\"running\",\"backend\":\"native\",\"autostart\":\"unknown\",\"release\":\"unknown\"}", esc(name), esc(field("jid")), esc(host), esc(field("path")), esc(field("ip4.addr")), esc(field("ip6.addr"))
        }
        END { printf "]" }
    '
}

configured_jails_json() {
    set --
    for file in "$etc_dir/jail.conf" "$etc_dir/jail.conf.d/"*.conf; do
        [ -r "$file" ] || continue
        set -- "$@" "$file"
    done

    [ "$#" -gt 0 ] || {
        printf '[]'
        return
    }

    awk -v top_config="$etc_dir/jail.conf" -v config_dir="$etc_dir/jail.conf.d" '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        function basename(path, parts, count) {
            count = split(path, parts, "/")
            return parts[count]
        }
        function jail_from_file(path, value) {
            value = basename(path)
            sub(/\.conf$/, "", value)
            return value
        }
        function emit(name, source) {
            if (name == "" || seen[name]++)
                return
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"jid\":\"\",\"hostname\":\"\",\"path\":\"\",\"ipv4\":\"\",\"ipv6\":\"\",\"state\":\"configured\",\"backend\":\"native\",\"autostart\":\"unknown\",\"release\":\"unknown\",\"source\":\"%s\"}", esc(name), esc(source)
        }
        BEGIN { printf "["; first = 1 }
        FILENAME == top_config && /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*\{/ {
            name = trim($1)
            emit(name, FILENAME)
            next
        }
        index(FILENAME, config_dir "/") == 1 && FILENAME ~ /\.conf$/ {
            emit(jail_from_file(FILENAME), FILENAME)
            nextfile
        }
        END { printf "]" }
    ' "$@" 2>/dev/null || printf '[]'
}

bastille_jails_json() {
    if ! command -v bastille >/dev/null 2>&1; then
        printf '[]'
        return
    fi

    config_output="$(run_bastille_read config ALL get host.hostname,path,ip4.addr,osrelease,boot 2>/dev/null || true)"
    if printf '%s\n' "$config_output" | awk '
        ($1 == "-" || $1 ~ /^[0-9]+$/) && ($3 == "host.hostname" || $3 == "path" || $3 == "ip4.addr" || $3 == "osrelease" || $3 == "boot") { found = 1 }
        END { exit found ? 0 : 1 }
    '; then
        printf '%s\n' "$config_output" |
        awk '
            function esc(value) {
                gsub(/\\/, "\\\\", value)
                gsub(/"/, "\\\"", value)
                return value
            }
            ($1 == "-" || $1 ~ /^[0-9]+$/) && ($3 == "host.hostname" || $3 == "path" || $3 == "ip4.addr" || $3 == "osrelease" || $3 == "boot") {
                jid = $1
                jail = $2
                property = $3
                $1 = $2 = $3 = ""
                sub(/^[[:space:]]+/, "", $0)
                value = $0
                if (!(jail in seen)) {
                    seen[jail] = 1
                    order[++count] = jail
                    jids[jail] = jid
                }
                values[jail, property] = value
            }
            END {
                printf "["
                for (i = 1; i <= count; i += 1) {
                    jail = order[i]
                    host = values[jail, "host.hostname"]
                    if (host == "") host = jail
                    state = jids[jail] == "0" || jids[jail] == "-" ? "stopped" : "running"
                    boot = values[jail, "boot"]
                    if (boot == "on" || boot == "yes" || boot == "YES") boot = "YES"
                    else if (boot == "off" || boot == "no" || boot == "NO") boot = "NO"
                    else boot = "unknown"
                    release = values[jail, "osrelease"]
                    if (release == "") release = "managed by Bastille"
                    if (i > 1) printf ","
                    printf "{\"name\":\"%s\",\"jid\":\"%s\",\"hostname\":\"%s\",\"path\":\"%s\",\"ipv4\":\"%s\",\"ipv6\":\"\",\"state\":\"%s\",\"backend\":\"bastille\",\"autostart\":\"%s\",\"release\":\"%s\"}", esc(jail), esc(jids[jail]), esc(host), esc(values[jail, "path"]), esc(values[jail, "ip4.addr"]), esc(state), esc(boot), esc(release)
                }
                printf "]"
            }
        '
        return
    fi

    run_bastille_list_all |
    awk '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        /^[[:space:]]*$/ || /^JID[[:space:]]/ || /^-/ { next }
        {
            jid = $1
            ip = $2
            host = $3
            path = $4
            state = jid == "0" || jid == "-" ? "stopped" : "running"
            if (host == "" || host == "-")
                host = path
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"jid\":\"%s\",\"hostname\":\"%s\",\"path\":\"%s\",\"ipv4\":\"%s\",\"ipv6\":\"\",\"state\":\"%s\",\"backend\":\"bastille\",\"autostart\":\"unknown\",\"release\":\"managed by Bastille\"}", esc(host), esc(jid), esc(host), esc(path), esc(ip), esc(state)
        }
        END { printf "]" }
    '
}

bastille_releases_json() {
    awk '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        {
            for (i = 1; i <= NF; i += 1) {
                value = $i
                gsub(/^[^0-9]+|[^A-Za-z0-9_.-]+$/, "", value)
                if (value ~ /^[0-9]+\.[0-9]+-RELEASE(-p[0-9]+)?$/ && !seen[value]++) {
                    if (!first) printf ","
                    first = 0
                    printf "\"%s\"", esc(value)
                }
            }
        }
        END { printf "]" }
    '
}

bastille_inventory() {
    config_output="$(run_bastille_read config ALL get host.hostname,ip4.addr 2>/dev/null || true)"
    if printf '%s\n' "$config_output" | awk '
        ($1 == "-" || $1 ~ /^[0-9]+$/) && ($3 == "host.hostname" || $3 == "ip4.addr") { found = 1 }
        END { exit found ? 0 : 1 }
    '; then
        printf '%s\n' "$config_output" |
        awk '
            ($1 == "-" || $1 ~ /^[0-9]+$/) && ($3 == "host.hostname" || $3 == "ip4.addr") {
                jail = $2
                property = $3
                $1 = $2 = $3 = ""
                sub(/^[[:space:]]+/, "", $0)
                if (!(jail in seen)) order[++count] = jail
                seen[jail] = 1
                values[jail, property] = $0
            }
            END {
                for (i = 1; i <= count; i += 1) {
                    jail = order[i]
                    print jail, values[jail, "ip4.addr"]
                }
            }
        '
        return
    fi

    run_bastille_list_all |
    awk '
        /^[[:space:]]*$/ || /^JID[[:space:]]/ || /^-/ { next }
        NF >= 3 { print $3, $2 }
    '
}

native_inventory() {
    command -v jls >/dev/null 2>&1 || return 0
    jls -n jid name host.hostname path ip4.addr ip6.addr 2>/dev/null |
    awk '
        function field(name, i, value) {
            for (i = 1; i <= NF; i += 1) {
                value = $i
                if (value ~ "^" name "=") {
                    sub("^" name "=", "", value)
                    gsub(/^"|"$/, "", value)
                    return value
                }
            }
            return ""
        }
        NF > 0 {
            name = field("name")
            if (name == "") name = field("host.hostname")
            print name, field("ip4.addr")
        }
    '
}

configured_name_exists() {
    target="$1"
    for file in "$etc_dir/jail.conf" "$etc_dir/jail.conf.d/"*.conf; do
        [ -r "$file" ] || continue
        if [ "$file" = "$etc_dir/jail.conf" ]; then
            awk -v target="$target" '
                /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*\{/ {
                    name = $1
                    if (name == target) found = 1
                }
                END { exit found ? 0 : 1 }
            ' "$file" && return 0
        else
            base="${file##*/}"
            base="${base%.conf}"
            [ "$base" = "$target" ] && return 0
        fi
    done
    return 1
}

release_is_bootstrapped() {
    target="$1"
    awk -v target="$target" '
        {
            for (i = 1; i <= NF; i += 1) {
                value = $i
                gsub(/^[^0-9]+|[^A-Za-z0-9_.-]+$/, "", value)
                if (value == target) found = 1
            }
        }
        END { exit found ? 0 : 1 }
    '
}

collect_jail_conflicts() {
    proposed_name="$1"
    proposed_address="$2"
    conflict_name_available=true
    conflict_address_available=true
    inventory=""

    if command -v bastille >/dev/null 2>&1; then
        inventory="$(bastille_inventory 2>/dev/null || true)"
    fi
    native_rows="$(native_inventory 2>/dev/null || true)"
    if [ -n "$native_rows" ]; then
        inventory="${inventory}${inventory:+
}${native_rows}"
    fi

    old_ifs="$IFS"
    IFS='
'
    for row in $inventory; do
        IFS="$old_ifs"
        set -- $row
        existing_name="${1:-}"
        existing_address="${2:-}"
        if [ "$existing_name" = "$proposed_name" ]; then
            conflict_name_available=false
        fi
        if [ "$proposed_address" != "inherit" ] && [ -n "$existing_address" ]; then
            normalized_proposed="${proposed_address##*|}"
            normalized_proposed="${normalized_proposed%%/*}"
            normalized_existing="${existing_address##*|}"
            normalized_existing="${normalized_existing%%/*}"
            if [ "$normalized_existing" = "$normalized_proposed" ]; then
                conflict_address_available=false
            fi
        fi
        IFS='
'
    done
    IFS="$old_ifs"
    if configured_name_exists "$proposed_name"; then
        conflict_name_available=false
    fi
}

release_is_host_compatible() {
    host="$1"
    jail="$2"
    awk -v host="$host" -v jail="$jail" '
        BEGIN {
            if (host !~ /^[0-9]+\.[0-9]+/ || jail !~ /^[0-9]+\.[0-9]+/)
                exit 0
            split(host, host_parts, ".")
            split(jail, jail_parts, ".")
            if (jail_parts[1] < host_parts[1] || (jail_parts[1] == host_parts[1] && jail_parts[2] <= host_parts[2]))
                exit 0
            exit 1
        }
    '
}

service_enabled() {
    name="$1"
    if command -v sysrc >/dev/null 2>&1; then
        sysrc -n "${name}_enable" 2>/dev/null || printf 'unknown\n'
    else
        printf 'unknown\n'
    fi
}

emit_snapshot() {
    last_tone="$(last_result_value tone)"
    last_message="$(last_result_value message)"
    last_timestamp="$(last_result_value timestamp)"
    [ -n "$last_tone" ] || last_tone="info"
    [ -n "$last_message" ] || last_message="Loaded jail status."

    native_enabled="$(service_enabled jail)"
    bastille_enabled="$(service_enabled bastille)"
    host_release="$(host_release_value | awk 'NF { print; exit }')"
    bastille_setup=false
    bastille_release_output=""
    if command -v bastille >/dev/null 2>&1 && bastille_storage_ready; then
        if bastille_release_output="$(run_bastille_read list releases 2>/dev/null)"; then
            bastille_setup=true
        fi
    fi

    printf '{'
    printf '"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "$last_message" | json_escape)"
    printf '"tools":{"jls":%s,"jail":%s,"service":%s,"bastille":%s,"mdo":%s},' \
        "$(command -v jls >/dev/null 2>&1 && printf true || printf false)" \
        "$(command -v jail >/dev/null 2>&1 && printf true || printf false)" \
        "$(command -v service >/dev/null 2>&1 && printf true || printf false)" \
        "$(command -v bastille >/dev/null 2>&1 && printf true || printf false)" \
        "$(command -v mdo >/dev/null 2>&1 && printf true || printf false)"
    printf '"services":{"jail":"%s","bastille":"%s"},' \
        "$(printf '%s' "$native_enabled" | json_escape)" \
        "$(printf '%s' "$bastille_enabled" | json_escape)"
    printf '"host_release":"%s","bastille_setup":%s,"bastille_releases":' \
        "$(printf '%s' "$host_release" | json_escape)" \
        "$bastille_setup"
    printf '%s\n' "$bastille_release_output" | bastille_releases_json
    printf ','
    printf '"storage":'
    emit_storage_snapshot
    printf ','
    printf '"network":'
    emit_network_snapshot
    printf ','
    printf '"running":'
    running_jails_json
    printf ',"configured":'
    configured_jails_json
    printf ',"bastille":'
    bastille_jails_json
    printf ',"last_result":{"tone":"%s","message":"%s","timestamp":"%s"}' \
        "$(printf '%s' "$last_tone" | json_escape)" \
        "$(printf '%s' "$last_message" | json_escape)" \
        "$(printf '%s' "$last_timestamp" | json_escape)"
    printf '}\n'
}

do_lifecycle() {
    verb="$1"
    name="$2"
    backend="${3:-native}"

    valid_name "$name" || {
        emit_action_result false "Invalid jail name." "Use the selected jail from the list."
        exit 1
    }

    case "$verb" in
        start|stop|restart)
            ;;
        *)
            emit_action_result false "Unknown jail action." "$verb"
            exit 1
            ;;
    esac

    case "$backend" in
        bastille)
            if ! command -v bastille >/dev/null 2>&1; then
                emit_action_result false "Bastille is unavailable." "Install Bastille or use a native jail entry."
                exit 1
            fi
            ;;
        native)
            ;;
        *)
            emit_action_result false "Unknown jail backend." "$backend"
            exit 1
            ;;
    esac

    if [ "$backend" = "bastille" ]; then
        if output="$(run_privileged bastille "$verb" "$name" 2>&1)"; then
            write_last_result "success" "$(printf '%s %s.' "$verb" "$name")"
            emit_action_result true "$(printf '%s %s.' "$verb" "$name")" "$output"
        else
            write_last_result "error" "Unable to ${verb} ${name}."
            emit_action_result false "Unable to ${verb} ${name}." "$output"
            exit 1
        fi
        return
    fi

    if command -v service >/dev/null 2>&1; then
        if output="$(run_privileged service jail "$verb" "$name" 2>&1)"; then
            write_last_result "success" "$(printf '%s %s.' "$verb" "$name")"
            emit_action_result true "$(printf '%s %s.' "$verb" "$name")" "$output"
        else
            write_last_result "error" "Unable to ${verb} ${name}."
            emit_action_result false "Unable to ${verb} ${name}." "$output"
            exit 1
        fi
    else
        emit_action_result false "The service command is unavailable." "Lifecycle actions need FreeBSD service(8)."
        exit 1
    fi
}

do_console() {
    name="$1"
    backend="${2:-native}"

    valid_name "$name" || {
        emit_action_result false "Invalid jail name." "Use the selected jail from the list."
        exit 1
    }

    case "$backend" in
        bastille)
            if ! command -v bastille >/dev/null 2>&1; then
                emit_action_result false "Bastille is unavailable." "Install Bastille or use a native jail entry."
                exit 1
            fi
            ;;
        native)
            if ! command -v jexec >/dev/null 2>&1; then
                emit_action_result false "The jexec command is unavailable." "Native jail consoles need FreeBSD jexec(8)."
                exit 1
            fi
            ;;
        *)
            emit_action_result false "Unknown jail backend." "$backend"
            exit 1
            ;;
    esac

    if command -v kitty >/dev/null 2>&1; then
        term="kitty"
    elif command -v xterm >/dev/null 2>&1; then
        term="xterm"
    else
        emit_action_result false "No terminal was found." "Install kitty or xterm to open jail consoles."
        exit 1
    fi

    if command -v mdo >/dev/null 2>&1; then
        privilege_prefix="mdo "
    else
        privilege_prefix=""
    fi

    if [ "$backend" = "bastille" ]; then
        console_command="${privilege_prefix}bastille console '$name'"
    else
        console_command="${privilege_prefix}jexec '$name' login -f root || ${privilege_prefix}jexec '$name' /bin/sh"
    fi

    "$term" sh -lc "$console_command; printf '\nConsole closed. Press Enter.'; read _" >/dev/null 2>&1 &

    write_last_result "info" "Opened console for ${name}."
    emit_action_result true "Opened console for ${name}." ""
}

do_preview() {
    name="${1:-}"
    release="${2:-}"
    address="${3:-}"
    autostart="${4:-yes}"

    valid_name "$name" || {
        emit_action_result false "Invalid jail name." "Use letters, numbers, dots, underscores, or hyphens."
        exit 1
    }
    valid_release "$release" || {
        emit_action_result false "Invalid FreeBSD release." "Use a release such as 15.0-RELEASE."
        exit 1
    }
    valid_address "$address" || {
        emit_action_result false "Invalid jail address." "Use an IPv4 or IPv6 address with an optional CIDR prefix."
        exit 1
    }
    valid_jail_ipv4 "$address" || {
        emit_action_result false "Invalid jail address." "The basic-jail workflow requires IPv4 with a CIDR prefix, such as 10.0.0.20/24."
        exit 1
    }
    case "$autostart" in
        yes|no)
            ;;
        *)
            emit_action_result false "Invalid autostart preference." "Choose yes or no."
            exit 1
            ;;
    esac

    bastille_installed=false
    bastille_setup=false
    storage_configured=false
    release_bootstrapped=false
    name_available=true
    address_available=true
    address_route_safe=false
    network_ready=false
    host_compatible=true
    host_release="$(host_release_value | awk 'NF { print; exit }')"
    release_output=""

    if command -v bastille >/dev/null 2>&1; then
        bastille_installed=true
        if bastille_storage_configured; then
            storage_configured=true
        fi
        if bastille_storage_ready && release_output="$(run_bastille_read list releases 2>/dev/null)"; then
            bastille_setup=true
        fi
        if printf '%s\n' "$release_output" | release_is_bootstrapped "$release"; then
            release_bootstrapped=true
        fi
    fi

    collect_jail_conflicts "$name" "$address"
    name_available="$conflict_name_available"
    address_available="$conflict_address_available"
    if address_route_available "$address"; then
        address_route_safe=true
    fi
    if bastille_network_ready; then
        network_ready=true
    fi

    if ! release_is_host_compatible "$host_release" "$release"; then
        host_compatible=false
    fi

    ready=true
    if [ "$bastille_installed" != true ] || [ "$storage_configured" != true ] || \
       [ "$name_available" != true ] || [ "$address_available" != true ] || \
       [ "$address_route_safe" != true ] || [ "$network_ready" != true ] || \
       [ "$host_compatible" != true ]; then
        ready=false
    fi

    bootstrap_command="bastille bootstrap --update ${release}"
    create_command="bastille create --thick"
    if [ "$autostart" = "no" ]; then
        create_command="${create_command} --no-boot"
    fi
    create_command="${create_command} ${name} ${release} ${address}"

    if [ "$bastille_installed" = true ] && [ "$bastille_setup" = true ]; then
        availability_note="Bastille is installed and its release inventory is readable."
    elif [ "$bastille_installed" = true ] && [ "$storage_configured" = true ]; then
        availability_note="Bastille storage is configured; the first release bootstrap will initialize its dataset hierarchy."
    elif [ "$bastille_installed" = true ]; then
        availability_note="Bastille is installed, but setup or privileged read access is still required."
    else
        availability_note="Bastille is not installed. Install and run bastille setup before using this plan."
    fi
    if [ "$release_bootstrapped" = true ]; then
        release_note="${release} is already bootstrapped, so the plan skips that step."
    else
        release_note="${release} is not in the bootstrapped release inventory, so the plan includes it."
    fi
    if [ "$name_available" = true ] && [ "$address_available" = true ]; then
        collision_note="No existing jail name or running IP address conflicts were found."
    else
        collision_note="Resolve the reported name or address conflict before running this plan."
    fi
    if [ "$network_ready" = true ] && [ "$address_route_safe" = true ]; then
        network_note="Bastille loopback and BSDRunner PF NAT are ready, and the jail address does not overlap an active host route."
    elif [ "$network_ready" = true ]; then
        network_note="Jail networking is configured, but the proposed address overlaps an active host route or interface."
    else
        network_note="Configure the Bastille loopback and BSDRunner PF jail rules before creating the jail."
    fi
    if [ "$host_compatible" = true ]; then
        host_note="The proposed release is compatible with the detected host release, or the host release is unknown."
    else
        host_note="The proposed release is newer than the detected host release. Upgrade the host or choose an older jail release."
    fi

    if [ "$ready" = true ]; then
        preview_message="Create preview ready. Nothing was changed."
    else
        preview_message="Create preview needs attention. Nothing was changed."
    fi

    printf '{'
    printf '"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "$preview_message" | json_escape)"
    printf '"backend":"bastille","mutates":false,"ready":%s,' "$ready"
    printf '"inputs":{"name":"%s","release":"%s","address":"%s","autostart":"%s","jail_type":"thick"},' \
        "$(printf '%s' "$name" | json_escape)" \
        "$(printf '%s' "$release" | json_escape)" \
        "$(printf '%s' "$address" | json_escape)" \
        "$autostart"
    printf '"checks":{"bastille_installed":%s,"bastille_setup":%s,"storage_configured":%s,"network_ready":%s,"release_bootstrapped":%s,"name_available":%s,"address_available":%s,"address_route_safe":%s,"host_release":"%s","host_compatible":%s},' \
        "$bastille_installed" "$bastille_setup" "$storage_configured" "$network_ready" "$release_bootstrapped" "$name_available" "$address_available" "$address_route_safe" \
        "$(printf '%s' "$host_release" | json_escape)" "$host_compatible"
    printf '"commands":['
    if [ "$release_bootstrapped" != true ]; then
        printf '"%s",' "$(printf '%s' "$bootstrap_command" | json_escape)"
    fi
    printf '"%s"],' "$(printf '%s' "$create_command" | json_escape)"
    printf '"notes":["This plan creates a thick service jail; Bastille owns its storage and jail.conf entry.","%s","%s","%s","%s","%s"]' \
        "$(printf '%s' "$availability_note" | json_escape)" \
        "$(printf '%s' "$release_note" | json_escape)" \
        "$(printf '%s' "$collision_note" | json_escape)" \
        "$(printf '%s' "$network_note" | json_escape)" \
        "$(printf '%s' "$host_note" | json_escape)"
    printf '}\n'
}

do_network_preview() {
    address="${1:-}"

    valid_jail_ipv4 "$address" || {
        emit_action_result false "Invalid jail address." "Use an IPv4 address with a CIDR prefix, such as 10.0.0.20/24."
        exit 1
    }
    route_safe=false
    address_route_available "$address" && route_safe=true
    loopback_interface="$(bastille_loopback_value)"
    external_interface="$(default_interface_value 2>/dev/null || true)"
    loopback_ready=false
    pf_running=false
    nat_ready=false
    rdr_ready=false
    anchor_ready=false
    ready=false
    network_interface_exists "$loopback_interface" && loopback_ready=true
    pf_is_running && pf_running=true
    network_nat_ready && nat_ready=true
    network_rdr_ready && rdr_ready=true
    network_filter_anchor_ready && anchor_ready=true
    if [ "$loopback_ready" = true ] && [ "$pf_running" = true ] && [ "$nat_ready" = true ] && \
       [ "$rdr_ready" = true ] && [ "$anchor_ready" = true ] && [ "$route_safe" = true ] && \
       [ -n "$external_interface" ]; then
        ready=true
    fi

    printf '{"ok":true,"mutates":false,"ready":%s,"address":"%s",' \
        "$ready" "$(printf '%s' "$address" | json_escape)"
    printf '"loopback_interface":"%s","external_interface":"%s",' \
        "$(printf '%s' "$loopback_interface" | json_escape)" \
        "$(printf '%s' "$external_interface" | json_escape)"
    printf '"checks":{"loopback_ready":%s,"pf_running":%s,"nat_ready":%s,"rdr_anchor_ready":%s,"filter_anchor_ready":%s,"address_route_safe":%s},' \
        "$loopback_ready" "$pf_running" "$nat_ready" "$rdr_ready" "$anchor_ready" "$route_safe"
    printf '"commands":['
    if [ "$loopback_ready" != true ]; then
        printf '"bastille setup --yes loopback",'
    fi
    printf '"bsdrunner-pf-backend.sh jail-network %s %s"],' \
        "$(printf '%s' "$loopback_interface" | json_escape)" \
        "$(printf '%s' "$external_interface" | json_escape)"
    printf '"notes":["The Bastille loopback is configured separately from PF.","BSDRunner renders, validates, installs, and reloads its managed PF profile with Bastille NAT and anchors.","Full bastille setup and bastille setup pf are not used."]}\n'
}

do_network_setup() {
    address="${1:-}"
    confirmation="${2:-}"

    valid_jail_ipv4 "$address" || {
        emit_action_result false "Invalid jail address." "Use an IPv4 address with a CIDR prefix, such as 10.0.0.20/24."
        exit 1
    }
    [ "$confirmation" = "$address" ] || {
        emit_action_result false "Network confirmation did not match." "Type the proposed jail address exactly."
        exit 1
    }
    command -v bastille >/dev/null 2>&1 || {
        emit_action_result false "Bastille is unavailable." "Install Bastille before configuring jail networking."
        exit 1
    }
    address_route_available "$address" || {
        emit_action_result false "The jail address overlaps an active host route or interface." "$address"
        exit 1
    }
    external_interface="$(default_interface_value 2>/dev/null || true)"
    [ -n "$external_interface" ] || {
        emit_action_result false "No default network interface was detected." "Connect the host to a network, then refresh."
        exit 1
    }
    [ -r "$pf_backend" ] || {
        emit_action_result false "The BSDRunner firewall backend is unavailable." "$pf_backend"
        exit 1
    }
    if bastille_network_ready; then
        emit_action_result true "Bastille jail networking is already ready." "No network change was needed."
        return
    fi

    loopback_interface="$(bastille_loopback_value)"
    loopback_output=""
    if ! network_interface_exists "$loopback_interface"; then
        if ! loopback_output="$(run_privileged bastille setup --yes loopback 2>&1)"; then
            write_last_result "error" "Unable to configure the Bastille loopback."
            emit_action_result false "Unable to configure the Bastille loopback." "$loopback_output"
            exit 1
        fi
        loopback_interface="$(bastille_loopback_value)"
        if ! network_interface_exists "$loopback_interface"; then
            write_last_result "error" "Bastille reported success, but its loopback interface is unavailable."
            emit_action_result false "Bastille loopback verification failed." "$loopback_output"
            exit 1
        fi
    fi

    if ! pf_output="$(sh "$pf_backend" jail-network "$loopback_interface" "$external_interface" 2>&1)"; then
        write_last_result "error" "The loopback is ready, but BSDRunner PF jail rules were not applied."
        emit_action_result false "The loopback is ready, but BSDRunner PF jail rules were not applied." "$pf_output"
        exit 1
    fi
    if ! printf '%s\n' "$pf_output" | grep -q '"ok":true'; then
        write_last_result "error" "The firewall backend returned an invalid network result."
        emit_action_result false "The firewall backend returned an invalid network result." "$pf_output"
        exit 1
    fi

    write_last_result "success" "Configured Bastille loopback and BSDRunner PF jail networking."
    emit_action_result true "Configured Bastille jail networking." "$loopback_output
$pf_output"
}

do_storage_preview() {
    pool="${1:-}"

    valid_pool "$pool" || {
        emit_action_result false "Invalid ZFS pool name." "Choose a detected pool."
        exit 1
    }
    command -v bastille >/dev/null 2>&1 || {
        emit_action_result false "Bastille is unavailable." "Install Bastille before configuring its storage."
        exit 1
    }
    zfs_pool_exists "$pool" || {
        emit_action_result false "The selected ZFS pool is unavailable." "$pool"
        exit 1
    }

    prefix="$(bastille_prefix_value 2>/dev/null || true)"
    [ -n "$prefix" ] || prefix="/usr/local/bastille"
    zfs_prefix="$(bastille_config_value bastille_zfs_prefix 2>/dev/null || true)"
    [ -n "$zfs_prefix" ] || zfs_prefix="bastille"
    target_dataset="${pool}/${zfs_prefix}"
    target_exists=false
    if command -v zfs >/dev/null 2>&1 && zfs list -H -o name "$target_dataset" >/dev/null 2>&1; then
        target_exists=true
    fi

    printf '{"ok":true,"mutates":false,"ready":true,'
    printf '"pool":"%s","prefix":"%s","target_dataset":"%s","target_exists":%s,' \
        "$(printf '%s' "$pool" | json_escape)" \
        "$(printf '%s' "$prefix" | json_escape)" \
        "$(printf '%s' "$target_dataset" | json_escape)" \
        "$target_exists"
    printf '"command":"bastille setup storage %s",' "$(printf '%s' "$pool" | json_escape)"
    printf '"notes":["This configures Bastille storage only; it does not change PF or networking.","The dataset hierarchy is created by the first Bastille release bootstrap.","Unrelated datasets are left untouched."]}\n'
}

do_storage_setup() {
    pool="${1:-}"
    confirmation="${2:-}"

    valid_pool "$pool" || {
        emit_action_result false "Invalid ZFS pool name." "Choose a detected pool."
        exit 1
    }
    [ "$confirmation" = "$pool" ] || {
        emit_action_result false "Storage confirmation did not match." "Type the selected pool name exactly."
        exit 1
    }
    command -v bastille >/dev/null 2>&1 || {
        emit_action_result false "Bastille is unavailable." "Install Bastille before configuring its storage."
        exit 1
    }
    zfs_pool_exists "$pool" || {
        emit_action_result false "The selected ZFS pool is unavailable." "$pool"
        exit 1
    }

    configured_pool="$(bastille_config_value bastille_zfs_zpool 2>/dev/null || true)"
    if bastille_zfs_configured; then
        if [ "$configured_pool" = "$pool" ]; then
            emit_action_result true "Bastille storage already uses ${pool}." "No configuration change was needed."
            return
        fi
        emit_action_result false "Bastille storage already uses another pool." "Configured pool: ${configured_pool}"
        exit 1
    fi
    if bastille_storage_ready; then
        emit_action_result false "Bastille storage is already initialized." "The UI will not convert an existing filesystem-backed installation to ZFS."
        exit 1
    fi

    if output="$(run_privileged bastille setup storage "$pool" 2>&1)"; then
        write_last_result "success" "Configured Bastille storage on ${pool}."
        emit_action_result true "Configured Bastille storage on ${pool}." "$output"
    else
        write_last_result "error" "Unable to configure Bastille storage on ${pool}."
        emit_action_result false "Unable to configure Bastille storage on ${pool}." "$output"
        exit 1
    fi
}

do_bootstrap() {
    release="${1:-}"
    confirmation="${2:-}"

    valid_release "$release" || {
        emit_action_result false "Invalid FreeBSD release." "Use a release such as 15.0-RELEASE."
        exit 1
    }
    [ "$confirmation" = "$release" ] || {
        emit_action_result false "Release confirmation did not match." "Return to the review step and confirm the selected release."
        exit 1
    }
    command -v bastille >/dev/null 2>&1 || {
        emit_action_result false "Bastille is unavailable." "Install and configure Bastille before bootstrapping a release."
        exit 1
    }
    bastille_storage_configured || {
        emit_action_result false "Bastille storage is not configured." "Choose a ZFS pool in the Storage step first."
        exit 1
    }
    if bastille_storage_ready; then
        if ! release_output="$(run_bastille_read list releases 2>/dev/null)"; then
            emit_action_result false "Bastille setup is not ready." "Make sure privileged inventory reads work."
            exit 1
        fi
        if printf '%s\n' "$release_output" | release_is_bootstrapped "$release"; then
            emit_action_result true "${release} is already bootstrapped." "No download was needed."
            return
        fi
    fi
    host_release="$(host_release_value | awk 'NF { print; exit }')"
    if ! release_is_host_compatible "$host_release" "$release"; then
        emit_action_result false "The jail release is newer than the host." "Choose a release compatible with ${host_release:-the host}."
        exit 1
    fi

    if output="$(run_privileged bastille bootstrap --update "$release" 2>&1)"; then
        write_last_result "success" "Bootstrapped ${release}."
        emit_action_result true "Bootstrapped ${release}." "$output"
    else
        write_last_result "error" "Unable to bootstrap ${release}."
        emit_action_result false "Unable to bootstrap ${release}." "$output"
        exit 1
    fi
}

do_create() {
    name="${1:-}"
    release="${2:-}"
    address="${3:-}"
    autostart="${4:-yes}"
    confirmation="${5:-}"

    valid_name "$name" || {
        emit_action_result false "Invalid jail name." "Use letters, numbers, dots, underscores, or hyphens."
        exit 1
    }
    valid_release "$release" || {
        emit_action_result false "Invalid FreeBSD release." "Use a release such as 15.0-RELEASE."
        exit 1
    }
    valid_address "$address" || {
        emit_action_result false "Invalid jail address." "Use an IPv4 or IPv6 address with an optional CIDR prefix."
        exit 1
    }
    valid_jail_ipv4 "$address" || {
        emit_action_result false "Invalid jail address." "The basic-jail workflow requires IPv4 with a CIDR prefix, such as 10.0.0.20/24."
        exit 1
    }
    case "$autostart" in
        yes|no)
            ;;
        *)
            emit_action_result false "Invalid autostart preference." "Choose yes or no."
            exit 1
            ;;
    esac
    [ "$confirmation" = "$name" ] || {
        emit_action_result false "Jail confirmation did not match." "Return to the review step and confirm the jail name."
        exit 1
    }
    command -v bastille >/dev/null 2>&1 || {
        emit_action_result false "Bastille is unavailable." "Install and configure Bastille before creating a jail."
        exit 1
    }
    bastille_storage_ready || {
        emit_action_result false "Bastille storage is not set up." "Run bastille setup before creating a jail."
        exit 1
    }
    if ! release_output="$(run_bastille_read list releases 2>/dev/null)"; then
        emit_action_result false "Bastille setup is not ready." "Run bastille setup and make sure privileged inventory reads work."
        exit 1
    fi
    if ! printf '%s\n' "$release_output" | release_is_bootstrapped "$release"; then
        emit_action_result false "The selected release is not bootstrapped." "Bootstrap ${release} before creating the jail."
        exit 1
    fi
    collect_jail_conflicts "$name" "$address"
    if [ "$conflict_name_available" != true ]; then
        emit_action_result false "The jail name is already in use." "$name"
        exit 1
    fi
    if [ "$conflict_address_available" != true ]; then
        emit_action_result false "The jail address is already in use." "$address"
        exit 1
    fi
    if ! address_route_available "$address"; then
        emit_action_result false "The jail address overlaps an active host route or interface." "$address"
        exit 1
    fi
    if ! bastille_network_ready; then
        emit_action_result false "Bastille jail networking is not ready." "Configure the Bastille loopback and BSDRunner PF jail rules first."
        exit 1
    fi

    if [ "$autostart" = "no" ]; then
        if output="$(run_privileged bastille create --thick --no-boot "$name" "$release" "$address" 2>&1)"; then
            create_ok=true
        else
            create_ok=false
        fi
    else
        if output="$(run_privileged bastille create --thick "$name" "$release" "$address" 2>&1)"; then
            create_ok=true
        else
            create_ok=false
        fi
    fi

    if [ "$create_ok" = true ]; then
        write_last_result "success" "Created ${name}."
        emit_action_result true "Created ${name}." "$output"
    else
        write_last_result "error" "Unable to create ${name}."
        emit_action_result false "Unable to create ${name}." "$output"
        exit 1
    fi
}

if [ -n "$fixture_file" ]; then
    case "$action" in
        snapshot)
            if [ ! -r "$fixture_file" ]; then
                emit_action_result false "Unable to load Jails demo data." "$fixture_file"
                exit 1
            fi
            cat "$fixture_file"
            exit 0
            ;;
        preview|storage-preview|network-preview)
            ;;
        *)
            emit_action_result false "Actions are disabled in demo mode." "Restart Jails normally to manage real jails."
            exit 1
            ;;
    esac
fi

case "$action" in
    snapshot)
        emit_snapshot
        ;;
    start|stop|restart)
        do_lifecycle "$action" "${2:-}" "${3:-native}"
        ;;
    console)
        do_console "${2:-}" "${3:-native}"
        ;;
    preview)
        do_preview "${2:-}" "${3:-}" "${4:-}" "${5:-yes}"
        ;;
    storage-preview)
        do_storage_preview "${2:-}"
        ;;
    storage-setup)
        do_storage_setup "${2:-}" "${3:-}"
        ;;
    network-preview)
        do_network_preview "${2:-}"
        ;;
    network-setup)
        do_network_setup "${2:-}" "${3:-}"
        ;;
    bootstrap)
        do_bootstrap "${2:-}" "${3:-}"
        ;;
    create)
        do_create "${2:-}" "${3:-}" "${4:-}" "${5:-yes}" "${6:-}"
        ;;
    *)
        emit_action_result false "Unknown Jails action." "$action"
        exit 1
        ;;
esac
