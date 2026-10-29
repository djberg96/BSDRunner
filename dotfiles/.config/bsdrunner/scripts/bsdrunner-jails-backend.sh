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

    bastille list -a 2>/dev/null |
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

    bootstrap_command="bastille bootstrap --update ${release}"
    create_command="bastille create --thick"
    if [ "$autostart" = "no" ]; then
        create_command="${create_command} --no-boot"
    fi
    create_command="${create_command} ${name} ${release} ${address}"

    if command -v bastille >/dev/null 2>&1; then
        availability_note="Bastille is installed. Review the plan before running it manually as root."
    else
        availability_note="Bastille is not installed. Install and run bastille setup before using this plan."
    fi

    printf '{'
    printf '"ok":true,'
    printf '"message":"Create preview ready. Nothing was changed.",'
    printf '"backend":"bastille","mutates":false,'
    printf '"inputs":{"name":"%s","release":"%s","address":"%s","autostart":"%s","jail_type":"thick"},' \
        "$(printf '%s' "$name" | json_escape)" \
        "$(printf '%s' "$release" | json_escape)" \
        "$(printf '%s' "$address" | json_escape)" \
        "$autostart"
    printf '"commands":["%s","%s"],' \
        "$(printf '%s' "$bootstrap_command" | json_escape)" \
        "$(printf '%s' "$create_command" | json_escape)"
    printf '"notes":["This plan creates a thick service jail; Bastille owns its storage and jail.conf entry.","%s"]' \
        "$(printf '%s' "$availability_note" | json_escape)"
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
