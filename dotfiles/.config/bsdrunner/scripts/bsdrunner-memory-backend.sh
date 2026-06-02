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

emit_error() {
    message="${1:-Unable to read process memory usage.}"
    printf '{"ok":false,"message":"%s","processes":[]}\n' "$(escape_json "$message")"
}

collect_ps_output() {
    output="$(ps ax -o pid= -o comm= -o rss= -o %cpu= 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o pid= -o comm= -o rss= -o pcpu= 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o pid -o comm -o rss -o %cpu 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    output="$(ps ax -o pid -o comm -o rss -o pcpu 2>/dev/null || true)"
    if [ -n "$output" ]; then
        printf '%s\n' "$output"
        return 0
    fi

    return 1
}

collect_procstat_output() {
    pids="$1"

    if [ -n "${BSDRUNNER_MEMORY_PROCSTAT_OUTPUT:-}" ]; then
        printf '%s\n' "$BSDRUNNER_MEMORY_PROCSTAT_OUTPUT"
        return 0
    fi

    if [ -z "$pids" ] || ! command -v procstat >/dev/null 2>&1; then
        return 1
    fi

    # shellcheck disable=SC2086
    procstat -v $pids 2>/dev/null || true
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

write_ps_table() {
    input="$1"
    output_file="$2"

    printf '%s\n' "$input" |
        awk '
            BEGIN {
                OFS = "\t"
            }

            NF >= 4 && $1 ~ /^[0-9]+$/ {
                pid = $1
                name = $2
                rss = $(NF - 1) + 0
                cpu = $NF + 0

                if (name == "" || rss <= 0) {
                    next
                }

                print pid, name, rss, cpu
            }
        ' > "$output_file"
}

write_pss_totals() {
    ps_file="$1"
    procstat_file="$2"
    output_file="$3"
    pages_kb="$4"

    awk -F '[ 	]+' -v page_kb="$pages_kb" '
        FNR == NR {
            process_name[$1] = $2
            rss_kb[$1] = $3 + 0
            cpu_percent[$1] = $4 + 0
            next
        }

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
            pid = $1
            res_pages = $(res_idx ? res_idx : 5) + 0
            pres_pages = $(pres_idx ? pres_idx : 6) + 0
            ref_count = $(ref_idx ? ref_idx : 7) + 0

            if (!(pid in process_name) || res_pages <= 0) {
                next
            }

            name = process_name[pid]
            shared_pages = res_pages - pres_pages
            if (shared_pages < 0) {
                shared_pages = 0
            }
            if (ref_count < 1) {
                ref_count = 1
            }

            pss_total[name] += (pres_pages + (shared_pages / ref_count)) * page_kb
            rss_total[name] += rss_kb[pid]
            cpu_total[name] += cpu_percent[pid]
            process_count[name] += 1
        }

        END {
            for (name in pss_total) {
                printf "%.0f\t%s\t%.1f\t%d\t%d\n", pss_total[name], name, cpu_total[name], process_count[name], rss_total[name]
            }
        }
    ' "$ps_file" "$procstat_file" |
        sort -rn -k1,1 |
        head -n 8 > "$output_file"
}

write_private_totals() {
    ps_file="$1"
    procstat_file="$2"
    output_file="$3"
    pages_kb="$4"

    awk -F '[ 	]+' -v page_kb="$pages_kb" '
        FNR == NR {
            process_name[$1] = $2
            rss_kb[$1] = $3 + 0
            cpu_percent[$1] = $4 + 0
            next
        }

        {
            for (i = 1; i <= NF; i += 1) {
                if ($i == "RES") {
                    res_idx = i
                } else if ($i == "SHD") {
                    shd_idx = i
                }
            }
        }

        $1 ~ /^[0-9]+$/ {
            pid = $1
            res_pages = $(res_idx ? res_idx : 5) + 0
            shared_count = $(shd_idx ? shd_idx : 8) + 0

            if (!(pid in process_name) || res_pages <= 0 || shared_count > 0) {
                next
            }

            name = process_name[pid]
            private_total[name] += res_pages * page_kb
            rss_total[name] += rss_kb[pid]
            cpu_total[name] += cpu_percent[pid]
            process_count[name] += 1
        }

        END {
            for (name in private_total) {
                printf "%d\t%s\t%.1f\t%d\t%d\n", private_total[name], name, cpu_total[name], process_count[name], rss_total[name]
            }
        }
    ' "$ps_file" "$procstat_file" |
        sort -rn -k1,1 |
        head -n 8 > "$output_file"
}

write_rss_totals() {
    ps_file="$1"
    output_file="$2"

    awk -F '	' '
        {
            name = $2
            rss = $3 + 0
            cpu = $4 + 0

            if (name == "" || rss <= 0) {
                next
            }

            rss_total[name] += rss
            cpu_total[name] += cpu
            process_count[name] += 1
        }

        END {
            for (name in rss_total) {
                printf "%d\t%s\t%.1f\t%d\t%d\n", rss_total[name], name, cpu_total[name], process_count[name], rss_total[name]
            }
        }
    ' "$ps_file" |
        sort -rn -k1,1 |
        head -n 8 > "$output_file"
}

emit_snapshot() {
    output_file="$1"
    mode="$2"

    generated_at="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
    top_total_kb="$(awk -F '	' '{ total += $1 } END { printf "%d", total }' "$output_file")"
    top_total_label="$(format_memory "$top_total_kb")"

    if [ "$mode" = "pss" ]; then
        message="PSS estimate by command using procstat RES, PRES, and REF."
        heading="Top 8 PSS"
        memory_kind="PSS Estimate"
    elif [ "$mode" = "private" ]; then
        message="Private resident estimate by command using procstat RES rows with SHD 0."
        heading="Top 8 Private"
        memory_kind="Private Estimate"
    else
        message="RSS totals by command; shared memory can be counted more than once."
        heading="Top 8 RSS Sum"
        memory_kind="RSS Sum"
    fi

    printf '{"ok":true,'
    printf '"message":"%s",' "$(escape_json "$message")"
    printf '"memory_kind":"%s",' "$(escape_json "$memory_kind")"
    printf '"memory_heading":"%s",' "$(escape_json "$heading")"
    printf '"generated_at":"%s",' "$(escape_json "$generated_at")"
    printf '"top_total_label":"%s",' "$(escape_json "$top_total_label")"
    printf '"processes":['

    first=1
    tab="$(printf '\t')"
    while IFS="$tab" read -r memory_kb name cpu count rss_kb; do
        [ -n "$name" ] || continue
        memory_mb=$(( (memory_kb + 1023) / 1024 ))
        memory_label="$(format_memory "$memory_kb")"

        if [ "$first" -eq 0 ]; then
            printf ','
        fi
        first=0

        printf '{"name":"%s","memory_kb":%s,"memory_mb":%s,"memory_label":"%s","rss_kb":%s,"cpu":"%s","count":%s}' \
            "$(escape_json "$name")" \
            "$memory_kb" \
            "$memory_mb" \
            "$(escape_json "$memory_label")" \
            "${rss_kb:-0}" \
            "$(escape_json "$cpu")" \
            "$count"
    done < "$output_file"

    printf ']}\n'
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

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-memory.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

ps_file="$tmp_dir/ps.tsv"
procstat_file="$tmp_dir/procstat.txt"
totals_file="$tmp_dir/totals.tsv"

write_ps_table "$ps_output" "$ps_file"

if [ ! -s "$ps_file" ]; then
    emit_error "No process memory data was available."
    exit 1
fi

pids="$(awk -F '	' '{ printf "%s ", $1 }' "$ps_file")"
procstat_output="$(collect_procstat_output "$pids" || true)"

if [ -n "$procstat_output" ]; then
    printf '%s\n' "$procstat_output" > "$procstat_file"
    if [ "${BSDRUNNER_MEMORY_MODE:-private}" = "pss" ]; then
        write_pss_totals "$ps_file" "$procstat_file" "$totals_file" "$(page_kb)"
    else
        write_private_totals "$ps_file" "$procstat_file" "$totals_file" "$(page_kb)"
    fi
fi

if [ -s "$totals_file" ]; then
    emit_snapshot "$totals_file" "${BSDRUNNER_MEMORY_MODE:-private}"
    exit 0
fi

write_rss_totals "$ps_file" "$totals_file"

if [ ! -s "$totals_file" ]; then
    emit_error "No process memory data was available."
    exit 1
fi

emit_snapshot "$totals_file" "rss"
