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

format_rss() {
    rss_kb="${1:-0}"
    rss_mb=$(( (rss_kb + 1023) / 1024 ))

    if [ "$rss_mb" -ge 1024 ]; then
        awk -v mb="$rss_mb" 'BEGIN { printf "%.1f GiB", mb / 1024 }'
    else
        printf '%s MiB' "$rss_mb"
    fi
}

emit_error() {
    message="${1:-Unable to read process memory usage.}"
    printf '{"ok":false,"message":"%s","processes":[]}\n' "$(escape_json "$message")"
}

collect_ps_output() {
    output="$(ps ax -o comm= -o rss= -o %cpu= 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o comm= -o rss= -o pcpu= 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o comm -o rss -o %cpu 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o comm -o rss -o pcpu 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps -axo comm=,rss=,%cpu= 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    return 1
}

if [ -n "${BSDRUNNER_MEMORY_PS_OUTPUT:-}" ]; then
    ps_output="$BSDRUNNER_MEMORY_PS_OUTPUT"
else
    if ! command -v ps >/dev/null 2>&1; then
        emit_error "ps is not available."
        exit 1
    fi

    ps_output="$(collect_ps_output || true)"
fi

if [ -z "$ps_output" ]; then
    emit_error "ps did not return process memory data."
    exit 1
fi

tmp_file="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-memory.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

printf '%s\n' "$ps_output" |
    awk '
        NF >= 3 {
            name = $1
            rss = $(NF - 1) + 0
            cpu = $NF + 0

            if (name == "" || rss <= 0) {
                next
            }

            rss_total[name] += rss
            cpu_total[name] += cpu
            process_count[name] += 1
        }

        END {
            for (name in rss_total) {
                printf "%d\t%s\t%.1f\t%d\n", rss_total[name], name, cpu_total[name], process_count[name]
            }
        }
    ' |
    sort -rn -k1,1 |
    head -n 8 > "$tmp_file"

if [ ! -s "$tmp_file" ]; then
    emit_error "No process memory data was available."
    exit 1
fi

generated_at="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
top_total_kb="$(awk -F '	' '{ total += $1 } END { printf "%d", total }' "$tmp_file")"
top_total_label="$(format_rss "$top_total_kb")"

printf '{"ok":true,'
printf '"message":"RSS totals by command; shared memory can be counted more than once.",'
printf '"generated_at":"%s",' "$(escape_json "$generated_at")"
printf '"top_total_label":"%s",' "$(escape_json "$top_total_label")"
printf '"processes":['

first=1
tab="$(printf '\t')"
while IFS="$tab" read -r rss_kb name cpu count; do
    [ -n "$name" ] || continue
    rss_mb=$(( (rss_kb + 1023) / 1024 ))
    rss_label="$(format_rss "$rss_kb")"

    if [ "$first" -eq 0 ]; then
        printf ','
    fi
    first=0

    printf '{"name":"%s","rss_kb":%s,"rss_mb":%s,"rss_label":"%s","cpu":"%s","count":%s}' \
        "$(escape_json "$name")" \
        "$rss_kb" \
        "$rss_mb" \
        "$(escape_json "$rss_label")" \
        "$(escape_json "$cpu")" \
        "$count"
done < "$tmp_file"

printf ']}\n'
