#!/bin/sh

set -eu

action="${1:-snapshot}"
view="${2:-browse}"
page_index="${3:-0}"
page_size="${4:-40}"
query="${5:-}"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

error_json() {
    message="$1"
    printf '{"ok":false,"message":"%s","packages":[],"summary":{"loaded":0,"installed":0,"page":1,"page_size":40,"has_prev":false,"has_next":false,"browse_count_label":"0","installed_count_label":"0","updates_count_label":"0","installed_size_label":"0 B"}}\n' \
        "$(json_escape "$message")"
}

normalize_records() {
    field_sep="$1"

    awk -v FS="$field_sep" '
        function clean(value) {
            gsub(/\r/, "", value)
            gsub(/\t+/, " ", value)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            gsub(/[[:space:]][[:space:]]+/, " ", value)
            return value
        }

        NF {
            for (i = 1; i <= 6; i += 1)
                $i = clean($i)

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $3
        }
    '
}

trim_file() {
    sed 's/[[:space:]][[:space:]]*/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

safe_number() {
    value="$1"
    fallback="$2"

    case "$value" in
        ''|*[!0-9]*)
            printf '%s\n' "$fallback"
            ;;
        *)
            printf '%s\n' "$value"
            ;;
    esac
}

count_lines() {
    file_path="$1"
    awk 'END { print NR + 0 }' "$file_path"
}

human_size_value() {
    bytes="$1"

    awk -v bytes="$bytes" '
        BEGIN {
            if (bytes == "" || bytes !~ /^[0-9]+$/) {
                print "0 B"
                exit
            }

            split("B KB MB GB TB", units, " ")
            value = bytes + 0
            idx = 1

            while (value >= 1024 && idx < 5) {
                value /= 1024
                idx += 1
            }

            if (idx == 1)
                printf "%d %s\n", value, units[idx]
            else
                printf "%.1f %s\n", value, units[idx]
        }
    '
}

local_pkg_disk_used_label() {
    stats_bytes_output="$(pkg stats -lb 2>/dev/null || true)"
    stats_bytes="$(printf '%s\n' "$stats_bytes_output" | awk -F ': *' '
        /Disk space occupied/ {
            value = $2
            gsub(/[^0-9]/, "", value)
            if (value != "") {
                print value
                exit
            }
        }
    ')"

    if [ -n "$stats_bytes" ]; then
        human_size_value "$stats_bytes"
        return
    fi

    stats_output="$(pkg stats -l 2>/dev/null || true)"
    stats_label="$(printf '%s\n' "$stats_output" | awk -F ': *' '
        /Disk space occupied/ {
            if ($2 != "") {
                print $2
                exit
            }
        }
    ')"

    if [ -n "$stats_label" ]; then
        printf '%s\n' "$stats_label"
        return
    fi

    human_size_value "$1"
}

collect_page_from_stdin() {
    meta_file="$1"
    needle="$2"
    offset="$3"
    limit="$4"

    awk -F '	' -v meta_file="$meta_file" -v needle="$needle" -v offset="$offset" -v limit="$limit" '
        function matches_record() {
            if (needle == "")
                return 1

            haystack = tolower($1 " " $3 " " $4)
            return index(haystack, needle) > 0
        }

        BEGIN {
            matched = 0
            loaded = 0
            has_next = 0
        }

        {
            if (!matches_record())
                next

            if (matched < offset) {
                matched += 1
                next
            }

            if (loaded < limit) {
                print
                loaded += 1
                matched += 1
                next
            }

            has_next = 1
            exit
        }

        END {
            printf "loaded=%d\nhas_next=%d\n", loaded, has_next > meta_file
        }
    '
}

collect_page_from_file() {
    source_file="$1"
    target_file="$2"
    meta_file="$3"
    needle="$4"
    offset="$5"
    limit="$6"

    collect_page_from_stdin "$meta_file" "$needle" "$offset" "$limit" <"$source_file" >"$target_file"
}

query_remote_record() {
    record_name="$1"
    query_format="$2"
    field_sep="$3"

    if pkg rquery "$query_format" "$record_name" 2>/dev/null | normalize_records "$field_sep" | awk 'NR == 1 { print; exit }'; then
        return 0
    fi

    return 1
}

enrich_browse_page() {
    page_file="$1"
    installed_file="$2"
    output_file="$3"

    awk -F '	' '
        function human_size(bytes) {
            if (bytes == "" || bytes !~ /^[0-9]+$/)
                return ""

            split("B KB MB GB TB", human_units, " ")
            human_size_value = bytes + 0
            human_unit_index = 1

            while (human_size_value >= 1024 && human_unit_index < 5) {
                human_size_value /= 1024
                human_unit_index += 1
            }

            if (human_unit_index == 1)
                return sprintf("%d %s", human_size_value, human_units[human_unit_index])

            return sprintf("%.1f %s", human_size_value, human_units[human_unit_index])
        }

        FNR == NR {
            installed_version[$1] = $2
            next
        }

        {
            installed = ($1 in installed_version) ? 1 : 0
            installed_value = installed ? installed_version[$1] : ""
            update_value = 0

            if (installed && installed_value != "" && installed_value != $2)
                update_value = 1

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\n",
                $1, $2, $3, $4, $5, $6, $7,
                installed, update_value, installed_value, human_size($6)
        }
    ' "$installed_file" "$page_file" >"$output_file"
}

enrich_installed_page() {
    page_file="$1"
    query_format="$2"
    field_sep="$3"
    output_file="$4"

    : >"$output_file"

    while IFS='	' read -r name installed_version comment origin website size_bytes description; do
        [ -n "$name" ] || continue

        remote_record="$(query_remote_record "$name" "$query_format" "$field_sep" || true)"

        version="$installed_version"
        merged_comment="$comment"
        merged_origin="$origin"
        merged_website="$website"
        merged_size="$size_bytes"
        merged_description="$description"
        update_available=0

        if [ -n "$remote_record" ]; then
            remote_version="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $2 }')"
            if [ -n "$remote_version" ]; then
                version="$remote_version"
                merged_comment="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $3 }')"
                merged_origin="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $4 }')"
                merged_website="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $5 }')"
                merged_size="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $6 }')"
                merged_description="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $7 }')"

                if [ "$installed_version" != "$remote_version" ]; then
                    comparison="$(pkg version -t "$installed_version" "$remote_version" 2>/dev/null || printf '=')"
                    if [ "$comparison" = "<" ]; then
                        update_available=1
                    fi
                fi
            fi
        fi

        size_text="$(
            awk -v bytes="$merged_size" '
                BEGIN {
                    if (bytes == "" || bytes !~ /^[0-9]+$/) {
                        print ""
                        exit
                    }

                    split("B KB MB GB TB", units, " ")
                    value = bytes + 0
                    idx = 1

                    while (value >= 1024 && idx < 5) {
                        value /= 1024
                        idx += 1
                    }

                    if (idx == 1)
                        printf "%d %s\n", value, units[idx]
                    else
                        printf "%.1f %s\n", value, units[idx]
                }
            '
        )"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\t%s\n' \
            "$name" \
            "$version" \
            "$merged_comment" \
            "$merged_origin" \
            "$merged_website" \
            "$merged_size" \
            "$merged_description" \
            "$update_available" \
            "$installed_version" \
            "$size_text" >>"$output_file"
    done <"$page_file"
}

build_updates_page() {
    installed_file="$1"
    query_format="$2"
    field_sep="$3"
    query_lc="$4"
    offset="$5"
    limit="$6"
    page_file="$7"
    meta_file="$8"

    : >"$page_file"

    matched=0
    loaded=0
    has_next=0

    while IFS='	' read -r name installed_version comment origin website size_bytes description; do
        [ -n "$name" ] || continue

        remote_record="$(query_remote_record "$name" "$query_format" "$field_sep" || true)"
        [ -n "$remote_record" ] || continue

        remote_version="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $2 }')"
        [ -n "$remote_version" ] || continue

        comparison="$(pkg version -t "$installed_version" "$remote_version" 2>/dev/null || printf '=')"
        [ "$comparison" = "<" ] || continue

        if [ -n "$query_lc" ]; then
            if ! printf '%s\n' "$remote_record" | awk -F '	' -v needle="$query_lc" '
                BEGIN { found = 0 }
                {
                    haystack = tolower($1 " " $3 " " $4)
                    if (index(haystack, needle) > 0)
                        found = 1
                }
                END { exit found ? 0 : 1 }
            '; then
                continue
            fi
        fi

        if [ "$matched" -lt "$offset" ]; then
            matched=$((matched + 1))
            continue
        fi

        if [ "$loaded" -lt "$limit" ]; then
            size_text="$(
                awk -v bytes="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $6 }')" '
                    BEGIN {
                        if (bytes == "" || bytes !~ /^[0-9]+$/) {
                            print ""
                            exit
                        }

                        split("B KB MB GB TB", units, " ")
                        value = bytes + 0
                        idx = 1

                        while (value >= 1024 && idx < 5) {
                            value /= 1024
                            idx += 1
                        }

                        if (idx == 1)
                            printf "%d %s\n", value, units[idx]
                        else
                            printf "%.1f %s\n", value, units[idx]
                    }
                '
            )"

            printf '%s\t1\t1\t%s\t%s\n' "$remote_record" "$installed_version" "$size_text" >>"$page_file"
            matched=$((matched + 1))
            loaded=$((loaded + 1))
            continue
        fi

        has_next=1
        break
    done <"$installed_file"

    printf 'loaded=%s\nhas_next=%s\n' "$loaded" "$has_next" >"$meta_file"
}

emit_json() {
    enriched_file="$1"
    message="$2"
    generated_at="$3"
    loaded="$4"
    installed_total="$5"
    current_page="$6"
    page_size="$7"
    has_prev="$8"
    has_next="$9"
    browse_label="${10}"
    installed_label="${11}"
    updates_label="${12}"
    installed_size_label="${13}"

    awk -F '	' \
        -v message="$message" \
        -v generated_at="$generated_at" \
        -v loaded="$loaded" \
        -v installed_total="$installed_total" \
        -v current_page="$current_page" \
        -v page_size="$page_size" \
        -v has_prev="$has_prev" \
        -v has_next="$has_next" \
        -v browse_label="$browse_label" \
        -v installed_label="$installed_label" \
        -v updates_label="$updates_label" \
        -v installed_size_label="$installed_size_label" '
        function escape_json(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            gsub(/\t/, " ", value)
            gsub(/\r/, " ", value)
            gsub(/\n/, " ", value)
            return value
        }

        function quote(value) {
            return "\"" escape_json(value) "\""
        }

        function repo_name(origin) {
            if (origin ~ /^base\//)
                return "FreeBSD-base"
            return "FreeBSD"
        }

        function category_name(origin) {
            category_count = split(origin, category_parts, "/")
            if (category_count > 1)
                return category_parts[1]
            return origin
        }

        BEGIN {
            first_record = 1
            printf "{"
            printf "\"ok\":true,"
            printf "\"message\":%s,", quote(message)
            printf "\"generated_at\":%s,", quote(generated_at)
            printf "\"packages\":["
        }

        {
            if (!first_record)
                printf ","

            package_comment = $3
            if (package_comment == "")
                package_comment = "No package summary available."

            package_description = $7
            if (package_description == "")
                package_description = package_comment

            printf "{"
            printf "\"name\":%s,", quote($1)
            printf "\"version\":%s,", quote($2)
            printf "\"installed_version\":%s,", quote($10)
            printf "\"installed\":%s,", ($8 == "1" ? "true" : "false")
            printf "\"update_available\":%s,", ($9 == "1" ? "true" : "false")
            printf "\"repo\":%s,", quote(repo_name($4))
            printf "\"origin\":%s,", quote($4)
            printf "\"category\":%s,", quote(category_name($4))
            printf "\"comment\":%s,", quote(package_comment)
            printf "\"description\":%s,", quote(package_description)
            printf "\"website\":%s,", quote($5)
            printf "\"license\":\"\","
            printf "\"size\":%s,", quote($11)
            printf "\"size_bytes\":%s,", ($6 == "" ? "0" : $6)
            printf "\"dependencies\":[]"
            printf "}"

            first_record = 0
        }

        END {
            printf "],"
            printf "\"summary\":{"
            printf "\"loaded\":%d,", loaded + 0
            printf "\"installed\":%d,", installed_total + 0
            printf "\"page\":%d,", current_page + 0
            printf "\"page_size\":%d,", page_size + 0
            printf "\"has_prev\":%s,", (has_prev == "true" ? "true" : "false")
            printf "\"has_next\":%s,", (has_next == "true" ? "true" : "false")
            printf "\"browse_count_label\":%s,", quote(browse_label)
            printf "\"installed_count_label\":%s,", quote(installed_label)
            printf "\"updates_count_label\":%s,", quote(updates_label)
            printf "\"installed_size_label\":%s", quote(installed_size_label)
            printf "}"
            printf "}\n"
        }
    ' "$enriched_file"
}

snapshot() {
    command -v pkg >/dev/null 2>&1 || {
        error_json "pkg is not installed or is not in PATH."
        exit 1
    }

    case "$view" in
        browse|installed|updates)
            ;;
        *)
            error_json "Unknown package view: $view"
            exit 1
            ;;
    esac

    page_index="$(safe_number "$page_index" "0")"
    page_size="$(safe_number "$page_size" "40")"

    if [ "$page_size" -lt 1 ]; then
        page_size=40
    fi

    if [ "$page_size" -gt 80 ]; then
        page_size=80
    fi

    offset=$((page_index * page_size))

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-software.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    field_sep="$(printf '\t')"
    query_format="$(printf '%%n%s%%v%s%%c%s%%o%s%%w%s%%sb' \
        "$field_sep" \
        "$field_sep" \
        "$field_sep" \
        "$field_sep" \
        "$field_sep")"
    query_lc="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"

    installed_tsv="$tmp_dir/installed.tsv"
    page_raw_tsv="$tmp_dir/page-raw.tsv"
    page_tsv="$tmp_dir/page.tsv"
    page_meta="$tmp_dir/page.meta"

    if ! pkg query -a "$query_format" 2>"$tmp_dir/installed.err" | normalize_records "$field_sep" >"$installed_tsv"; then
        installed_error="$(tr '\n' ' ' <"$tmp_dir/installed.err" | trim_file)"
        error_json "Unable to query installed pkg metadata. ${installed_error}"
        exit 1
    fi

    installed_total="$(count_lines "$installed_tsv")"
    installed_size_bytes="$(awk -F '	' '{ if ($6 ~ /^[0-9]+$/) total += $6 } END { print total + 0 }' "$installed_tsv")"
    installed_size_label="$(local_pkg_disk_used_label "$installed_size_bytes")"

    case "$view" in
        browse)
            if ! pkg rquery -a "$query_format" 2>"$tmp_dir/remote.err" | normalize_records "$field_sep" | collect_page_from_stdin "$page_meta" "$query_lc" "$offset" "$page_size" >"$page_raw_tsv"; then
                remote_error="$(tr '\n' ' ' <"$tmp_dir/remote.err" | trim_file)"
                error_json "Unable to query remote pkg metadata. ${remote_error}"
                exit 1
            fi

            enrich_browse_page "$page_raw_tsv" "$installed_tsv" "$page_tsv"
            ;;
        installed)
            collect_page_from_file "$installed_tsv" "$page_raw_tsv" "$page_meta" "$query_lc" "$offset" "$page_size"
            enrich_installed_page "$page_raw_tsv" "$query_format" "$field_sep" "$page_tsv"
            ;;
        updates)
            build_updates_page "$installed_tsv" "$query_format" "$field_sep" "$query_lc" "$offset" "$page_size" "$page_tsv" "$page_meta"
            ;;
    esac

    loaded="$(awk -F '=' '$1 == "loaded" { print $2 }' "$page_meta")"
    has_next_flag="$(awk -F '=' '$1 == "has_next" { print $2 }' "$page_meta")"
    has_prev_flag="false"

    if [ "$page_index" -gt 0 ]; then
        has_prev_flag="true"
    fi

    if [ "$has_next_flag" = "1" ]; then
        has_next_flag="true"
    else
        has_next_flag="false"
    fi

    browse_count_label="--"
    installed_count_label="$installed_total"
    updates_count_label="--"

    case "$view" in
        browse)
            browse_count_label="$loaded"
            message="Loaded page $((page_index + 1)) of live package metadata from pkg."
            ;;
        installed)
            browse_count_label="--"
            message="Loaded page $((page_index + 1)) of installed packages."
            ;;
        updates)
            updates_count_label="$loaded"
            message="Loaded page $((page_index + 1)) of available package updates."
            ;;
    esac

    generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    emit_json \
        "$page_tsv" \
        "$message" \
        "$generated_at" \
        "$loaded" \
        "$installed_total" \
        "$((page_index + 1))" \
        "$page_size" \
        "$has_prev_flag" \
        "$has_next_flag" \
        "$browse_count_label" \
        "$installed_count_label" \
        "$updates_count_label" \
        "$installed_size_label"
}

case "$action" in
    snapshot)
        snapshot
        ;;
    *)
        error_json "Unknown query action: $action"
        exit 1
        ;;
esac
