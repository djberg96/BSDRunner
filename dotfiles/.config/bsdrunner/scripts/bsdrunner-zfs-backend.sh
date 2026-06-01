#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

action="${1:-snapshot}"
state_dir="${HOME}/.config/bsdrunner/zfs"
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

run_privileged() {
    if command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    else
        "$@"
    fi
}

valid_dataset() {
    case "${1:-}" in
        ""|*" "*|*@*|*";"*|*"|"*|*"&"*|*">"*|*"<"*|*"\\"*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

valid_snapshot() {
    case "${1:-}" in
        ""|*" "*|*@|@*|*@*@*|*";"*|*"|"*|*"&"*|*">"*|*"<"*|*"\\"*)
            return 1
            ;;
        *@*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

valid_snapshot_label() {
    case "${1:-}" in
        ""|*[!A-Za-z0-9_.-]*)
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

emit_pool_json() {
    if ! command -v zpool >/dev/null 2>&1; then
        printf '[]'
        return
    fi

    zpool list -H -o name,size,alloc,free,cap,health 2>/dev/null |
    awk -F '\t' '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        NF >= 6 {
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"size\":\"%s\",\"alloc\":\"%s\",\"free\":\"%s\",\"cap\":\"%s\",\"health\":\"%s\"}", esc($1), esc($2), esc($3), esc($4), esc($5), esc($6)
        }
        END { printf "]" }
    '
}

emit_dataset_json() {
    if ! command -v zfs >/dev/null 2>&1; then
        printf '[]'
        return
    fi

    zfs list -H -t filesystem,volume -o name,used,avail,refer,mountpoint,type 2>/dev/null |
    awk -F '\t' '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        NF >= 6 {
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"used\":\"%s\",\"avail\":\"%s\",\"refer\":\"%s\",\"mountpoint\":\"%s\",\"type\":\"%s\"}", esc($1), esc($2), esc($3), esc($4), esc($5), esc($6)
        }
        END { printf "]" }
    '
}

emit_snapshot_json() {
    if ! command -v zfs >/dev/null 2>&1; then
        printf '[]'
        return
    fi

    zfs list -H -t snapshot -o name,used,refer,creation -s creation 2>/dev/null |
    tail -n 100 |
    awk -F '\t' '
        function esc(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            return value
        }
        BEGIN { printf "["; first = 1 }
        NF >= 4 {
            dataset = $1
            label = $1
            sub(/@.*/, "", dataset)
            sub(/.*@/, "", label)
            if (!first) printf ","
            first = 0
            printf "{\"name\":\"%s\",\"dataset\":\"%s\",\"snapshot\":\"%s\",\"used\":\"%s\",\"refer\":\"%s\",\"created\":\"%s\"}", esc($1), esc(dataset), esc(label), esc($2), esc($3), esc($4)
        }
        END { printf "]" }
    '
}

emit_snapshot() {
    last_tone="$(last_result_value tone)"
    last_message="$(last_result_value message)"
    last_timestamp="$(last_result_value timestamp)"

    [ -n "$last_tone" ] || last_tone="info"
    [ -n "$last_message" ] || last_message="Loaded ZFS status."

    printf '{'
    printf '"ok":true,'
    printf '"message":"%s",' "$(printf '%s' "$last_message" | json_escape)"
    printf '"tools":{"zfs":%s,"zpool":%s},' \
        "$(if command -v zfs >/dev/null 2>&1; then printf true; else printf false; fi)" \
        "$(if command -v zpool >/dev/null 2>&1; then printf true; else printf false; fi)"
    printf '"pools":'
    emit_pool_json
    printf ',"datasets":'
    emit_dataset_json
    printf ',"snapshots":'
    emit_snapshot_json
    printf ',"last_result":{"tone":"%s","message":"%s","timestamp":"%s"}' \
        "$(printf '%s' "$last_tone" | json_escape)" \
        "$(printf '%s' "$last_message" | json_escape)" \
        "$(printf '%s' "$last_timestamp" | json_escape)"
    printf '}\n'
}

do_create_snapshot() {
    dataset="$1"
    label="${2:-}"
    recursive="${3:-}"

    valid_dataset "$dataset" || {
        emit_action_result false "Invalid dataset name." "Select a filesystem or volume from the list."
        exit 1
    }

    if [ -z "$label" ]; then
        label="bsdrunner-$(date '+%Y%m%d-%H%M%S')"
    fi

    valid_snapshot_label "$label" || {
        emit_action_result false "Invalid snapshot label." "Use only letters, numbers, dot, underscore, or hyphen."
        exit 1
    }

    snapshot_name="${dataset}@${label}"

    case "$recursive" in
        ""|recursive)
            ;;
        *)
            emit_action_result false "Invalid recursive option." "Use the confirmation checkbox to create recursive snapshots."
            exit 1
            ;;
    esac

    if [ "$recursive" = "recursive" ]; then
        if output="$(run_privileged zfs snapshot -r "$snapshot_name" 2>&1)"; then
            write_last_result "success" "Created recursive snapshot ${snapshot_name}."
            emit_action_result true "Created recursive snapshot ${snapshot_name}." "$output"
        else
            write_last_result "error" "Unable to create recursive snapshot."
            emit_action_result false "Unable to create recursive snapshot." "$output"
            exit 1
        fi
    elif output="$(run_privileged zfs snapshot "$snapshot_name" 2>&1)"; then
        write_last_result "success" "Created snapshot ${snapshot_name}."
        emit_action_result true "Created snapshot ${snapshot_name}." "$output"
    else
        write_last_result "error" "Unable to create snapshot."
        emit_action_result false "Unable to create snapshot." "$output"
        exit 1
    fi
}

do_destroy_snapshot() {
    snapshot_name="$1"
    valid_snapshot "$snapshot_name" || {
        emit_action_result false "Invalid snapshot name." "Select a snapshot from the list."
        exit 1
    }

    if output="$(run_privileged zfs destroy "$snapshot_name" 2>&1)"; then
        write_last_result "warning" "Destroyed snapshot ${snapshot_name}."
        emit_action_result true "Destroyed snapshot ${snapshot_name}." "$output"
    else
        write_last_result "error" "Unable to destroy snapshot."
        emit_action_result false "Unable to destroy snapshot." "$output"
        exit 1
    fi
}

do_rollback_snapshot() {
    snapshot_name="$1"
    valid_snapshot "$snapshot_name" || {
        emit_action_result false "Invalid snapshot name." "Select a snapshot from the list."
        exit 1
    }

    if output="$(run_privileged zfs rollback "$snapshot_name" 2>&1)"; then
        write_last_result "warning" "Rolled back to ${snapshot_name}."
        emit_action_result true "Rolled back to ${snapshot_name}." "$output"
    else
        write_last_result "error" "Unable to roll back snapshot."
        emit_action_result false "Unable to roll back snapshot." "$output"
        exit 1
    fi
}

case "$action" in
    snapshot)
        emit_snapshot
        ;;
    create-snapshot)
        do_create_snapshot "${2:-}" "${3:-}" "${4:-}"
        ;;
    destroy-snapshot)
        do_destroy_snapshot "${2:-}"
        ;;
    rollback-snapshot)
        do_rollback_snapshot "${2:-}"
        ;;
    *)
        emit_action_result false "Unknown ZFS action." "$action"
        exit 1
        ;;
esac
