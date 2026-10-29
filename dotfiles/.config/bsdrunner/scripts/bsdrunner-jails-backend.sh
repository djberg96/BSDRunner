#!/bin/sh

set -eu

test_mode="${BSDRUNNER_JAILS_TEST_MODE:-0}"
if [ "$test_mode" = "1" ]; then
    PATH="${BSDRUNNER_JAILS_TEST_PATH:-/usr/bin:/bin}"
    etc_dir="${BSDRUNNER_JAILS_TEST_ETC_DIR:-/etc}"
    state_dir="${BSDRUNNER_JAILS_TEST_STATE_DIR:-${TMPDIR:-/tmp}/bsdrunner-jails-test-state}"
else
    PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
    etc_dir="/etc"
    state_dir="${HOME}/.config/bsdrunner/jails"
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
    if command -v bastille >/dev/null 2>&1; then
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
    release_bootstrapped=false
    name_available=true
    address_available=true
    host_compatible=true
    host_release="$(host_release_value | awk 'NF { print; exit }')"
    release_output=""
    inventory=""

    if command -v bastille >/dev/null 2>&1; then
        bastille_installed=true
        if release_output="$(run_bastille_read list releases 2>/dev/null)"; then
            bastille_setup=true
        fi
        if printf '%s\n' "$release_output" | release_is_bootstrapped "$release"; then
            release_bootstrapped=true
        fi
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
        [ "$existing_name" = "$name" ] && name_available=false
        if [ "$address" != "inherit" ] && [ -n "$existing_address" ]; then
            proposed_address="${address##*|}"
            proposed_address="${proposed_address%%/*}"
            existing_address="${existing_address##*|}"
            existing_address="${existing_address%%/*}"
            [ "$existing_address" = "$proposed_address" ] && address_available=false
        fi
        IFS='
'
    done
    IFS="$old_ifs"
    if configured_name_exists "$name"; then
        name_available=false
    fi

    if ! awk -v host="$host_release" -v jail="$release" '
        BEGIN {
            if (host !~ /^[0-9]+\.[0-9]+/ || jail !~ /^[0-9]+\.[0-9]+/)
                exit 0
            split(host, host_parts, ".")
            split(jail, jail_parts, ".")
            if (jail_parts[1] < host_parts[1] || (jail_parts[1] == host_parts[1] && jail_parts[2] <= host_parts[2]))
                exit 0
            exit 1
        }
    '; then
        host_compatible=false
    fi

    ready=true
    if [ "$bastille_installed" != true ] || [ "$bastille_setup" != true ] || \
       [ "$name_available" != true ] || [ "$address_available" != true ] || \
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
    printf '"checks":{"bastille_installed":%s,"bastille_setup":%s,"release_bootstrapped":%s,"name_available":%s,"address_available":%s,"host_release":"%s","host_compatible":%s},' \
        "$bastille_installed" "$bastille_setup" "$release_bootstrapped" "$name_available" "$address_available" \
        "$(printf '%s' "$host_release" | json_escape)" "$host_compatible"
    printf '"commands":['
    if [ "$release_bootstrapped" != true ]; then
        printf '"%s",' "$(printf '%s' "$bootstrap_command" | json_escape)"
    fi
    printf '"%s"],' "$(printf '%s' "$create_command" | json_escape)"
    printf '"notes":["This plan creates a thick service jail; Bastille owns its storage and jail.conf entry.","%s","%s","%s","%s"]' \
        "$(printf '%s' "$availability_note" | json_escape)" \
        "$(printf '%s' "$release_note" | json_escape)" \
        "$(printf '%s' "$collision_note" | json_escape)" \
        "$(printf '%s' "$host_note" | json_escape)"
    printf '}\n'
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
        preview)
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
    *)
        emit_action_result false "Unknown Jails action." "$action"
        exit 1
        ;;
esac
