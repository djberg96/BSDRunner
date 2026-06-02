#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

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

format_memory() {
    memory_kb="${1:-0}"
    memory_mb=$(( (memory_kb + 1023) / 1024 ))

    if [ "$memory_mb" -ge 1024 ]; then
        awk -v mb="$memory_mb" 'BEGIN { printf "%.1f GiB", mb / 1024 }'
    else
        printf '%s MiB' "$memory_mb"
    fi
}

page_kb() {
    page_size="$(getconf PAGE_SIZE 2>/dev/null || true)"
    case "$page_size" in
        ''|*[!0-9]*)
            page_size="$(sysctl -n hw.pagesize 2>/dev/null || true)"
            ;;
    esac

    case "$page_size" in
        ''|*[!0-9]*)
            printf '4\n'
            ;;
        *)
            printf '%s\n' "$(( page_size / 1024 ))"
            ;;
    esac
}

physical_memory_kb() {
    if [ -n "${BSDRUNNER_MEMORY_PHYSMEM_KB:-}" ]; then
        printf '%s\n' "$BSDRUNNER_MEMORY_PHYSMEM_KB"
        return 0
    fi

    bytes="$(sysctl -n hw.physmem 2>/dev/null || true)"
    case "$bytes" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            printf '%s\n' "$(( bytes / 1024 ))"
            ;;
    esac
}

procstat_output() {
    if [ -n "${BSDRUNNER_MEMORY_PROCSTAT_OUTPUT:-}" ]; then
        printf '%s\n' "$BSDRUNNER_MEMORY_PROCSTAT_OUTPUT"
        return 0
    fi

    if ! command -v procstat >/dev/null 2>&1; then
        return 1
    fi

    procstat -v -a 2>/dev/null || true
}

rss_total_kb() {
    ps ax -o rss= 2>/dev/null |
        awk '{ total += $1 + 0 } END { printf "%.0f\n", total }'
}

pss_total_kb() {
    input="$1"
    pages_kb="$2"

    printf '%s\n' "$input" |
        awk -F '[ 	]+' -v page_kb="$pages_kb" '
            {
                for (i = 1; i <= NF; i += 1) {
                    if ($i == "RES") {
                        res_idx = i
                    } else if ($i == "PRES") {
                        pres_idx = i
                    } else if ($i == "REF") {
                        ref_idx = i
                    }
                }
            }

            $1 ~ /^[0-9]+$/ {
                res_pages = $(res_idx ? res_idx : 5) + 0
                pres_pages = $(pres_idx ? pres_idx : 6) + 0
                ref_count = $(ref_idx ? ref_idx : 7) + 0

                if (res_pages <= 0) {
                    next
                }

                shared_pages = res_pages - pres_pages
                if (shared_pages < 0) {
                    shared_pages = 0
                }
                if (ref_count < 1) {
                    ref_count = 1
                }

                total += (pres_pages + (shared_pages / ref_count)) * page_kb
            }

            END {
                printf "%.0f\n", total
            }
        '
}

emit_waybar() {
    text="$1"
    tooltip="$2"
    percentage="${3:-0}"
    class_name="${4:-normal}"

    printf '{"text":"%s","tooltip":"%s","percentage":%s,"class":"%s"}\n' \
        "$(escape_json "$text")" \
        "$(escape_json "$tooltip")" \
        "$percentage" \
        "$(escape_json "$class_name")"
}

mode="PSS estimate"
memory_kb=0
data="$(procstat_output || true)"

if [ -n "$data" ]; then
    memory_kb="$(pss_total_kb "$data" "$(page_kb)")"
fi

case "$memory_kb" in
    ''|*[!0-9]*|0)
        mode="RSS fallback"
        memory_kb="$(rss_total_kb || printf '0\n')"
        ;;
esac

case "$memory_kb" in
    ''|*[!0-9]*)
        memory_kb=0
        ;;
esac

memory_label="$(format_memory "$memory_kb")"
physmem_kb="$(physical_memory_kb || true)"

case "$physmem_kb" in
    ''|*[!0-9]*|0)
        tooltip="$(printf '%s\n%s' "$mode: $memory_label" "Click for private memory by process")"
        emit_waybar "$memory_label" "$tooltip" 0 "unknown"
        ;;
    *)
        percent="$(( (memory_kb * 100 + physmem_kb / 2) / physmem_kb ))"
        total_label="$(format_memory "$physmem_kb")"
        class_name="normal"
        if [ "$percent" -ge 90 ]; then
            class_name="critical"
        elif [ "$percent" -ge 75 ]; then
            class_name="warning"
        fi

        tooltip="$(printf '%s\n%s' "$mode: $memory_label / $total_label" "Click for private memory by process")"
        emit_waybar "${percent}%" "$tooltip" "$percent" "$class_name"
        ;;
esac
