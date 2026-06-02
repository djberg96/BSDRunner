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

sysctl_value() {
    if [ -n "${BSDRUNNER_MEMORY_SYSCTL_PREFIX:-}" ]; then
        env_name="$(printf '%s' "$1" | awk '{ gsub(/\./, "_"); print toupper($0) }')"
        eval "value=\${BSDRUNNER_MEMORY_SYSCTL_PREFIX_${env_name}:-}"
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    sysctl -n "$1" 2>/dev/null || printf '0\n'
}

numeric_value() {
    value="${1:-0}"
    case "$value" in
        ''|*[!0-9]*)
            printf '0\n'
            ;;
        *)
            printf '%s\n' "$value"
            ;;
    esac
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

pages_kb="$(page_kb)"
page_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_page_count)")"
active_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_active_count)")"
wire_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_wire_count)")"
laundry_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_laundry_count)")"
inactive_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_inactive_count)")"
cache_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_cache_count)")"
free_count="$(numeric_value "$(sysctl_value vm.stats.vm.v_free_count)")"

pressure_pages="$(( active_count + wire_count + laundry_count ))"
reclaimable_pages="$(( inactive_count + cache_count ))"
total_kb="$(( page_count * pages_kb ))"
pressure_kb="$(( pressure_pages * pages_kb ))"
reclaimable_kb="$(( reclaimable_pages * pages_kb ))"
free_kb="$(( free_count * pages_kb ))"

if [ "$page_count" -le 0 ]; then
    emit_waybar "--" "Unable to read FreeBSD VM memory counters" 0 "unknown"
    exit 0
fi

percent="$(( (pressure_pages * 100 + page_count / 2) / page_count ))"
pressure_label="$(format_memory "$pressure_kb")"
reclaimable_label="$(format_memory "$reclaimable_kb")"
free_label="$(format_memory "$free_kb")"
total_label="$(format_memory "$total_kb")"
class_name="normal"

if [ "$percent" -ge 90 ]; then
    class_name="critical"
elif [ "$percent" -ge 75 ]; then
    class_name="warning"
fi

tooltip="$(printf '%s\n%s\n%s\n%s' \
    "Memory pressure: $pressure_label / $total_label" \
    "Reclaimable inactive/cache: $reclaimable_label" \
    "Free: $free_label" \
    "Click for private memory by process")"
emit_waybar "${percent}%" "$tooltip" "$percent" "$class_name"
