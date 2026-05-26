#!/bin/sh

set -eu

action="${1:-snapshot}"
view="${2:-browse}"
page_index="${3:-0}"
page_size="${4:-40}"
query="${5:-}"
empty_field_token="__EMPTY__"

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

    awk -v FS="$field_sep" -v empty_field_token="$empty_field_token" '
        function clean(value) {
            gsub(/\r/, "", value)
            gsub(/\t+/, " ", value)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            gsub(/[[:space:]][[:space:]]+/, " ", value)
            return value
        }

        NF {
            for (i = 1; i <= 7; i += 1)
                $i = clean($i)

            for (i = 1; i <= 7; i += 1) {
                if ($i == "")
                    $i = empty_field_token
            }

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $3, $7
        }
    '
}

encode_empty_field() {
    if [ -n "${1:-}" ]; then
        printf '%s\n' "$1"
    else
        printf '%s\n' "$empty_field_token"
    fi
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
    text_filter="$2"
    category_filter="$3"
    package_filter="$4"
    offset="$5"
    limit="$6"

    awk -F '	' -v meta_file="$meta_file" -v text_filter="$text_filter" -v category_filter="$category_filter" -v package_filter="$package_filter" -v offset="$offset" -v limit="$limit" '
        function matches_package_name(name, filter, prefix_mode, base_filter) {
            if (filter == "")
                return 1

            prefix_mode = (filter ~ /\*$/)
            base_filter = prefix_mode ? substr(filter, 1, length(filter) - 1) : filter
            if (base_filter == "")
                return 1

            name = tolower(name)
            if (prefix_mode)
                return index(name, base_filter) == 1

            return index(name, base_filter) > 0
        }

        function matches_record() {
            split($4, origin_parts, "/")
            category = tolower(origin_parts[1])
            if (category_filter != "" && category != category_filter)
                return 0

            if (!matches_package_name($1, package_filter))
                return 0

            if (text_filter == "")
                return 1

            haystack = tolower($1 " " $3 " " $4)
            return index(haystack, text_filter) > 0
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
    text_filter="$4"
    category_filter="$5"
    package_filter="$6"
    offset="$7"
    limit="$8"

    collect_page_from_stdin "$meta_file" "$text_filter" "$category_filter" "$package_filter" "$offset" "$limit" <"$source_file" >"$target_file"
}

collect_browse_page() {
    installed_file="$1"
    source_file="$2"
    target_file="$3"
    meta_file="$4"
    text_filter="$5"
    category_filter="$6"
    package_filter="$7"
    installed_filter="$8"
    offset="$9"
    limit="${10}"

    awk -F '	' \
        -v meta_file="$meta_file" \
        -v text_filter="$text_filter" \
        -v category_filter="$category_filter" \
        -v package_filter="$package_filter" \
        -v installed_filter="$installed_filter" \
        -v offset="$offset" \
        -v limit="$limit" \
        -v empty_field_token="$empty_field_token" '
        function matches_package_name(name, filter, prefix_mode, base_filter) {
            if (filter == "")
                return 1

            prefix_mode = (filter ~ /\*$/)
            base_filter = prefix_mode ? substr(filter, 1, length(filter) - 1) : filter
            if (base_filter == "")
                return 1

            name = tolower(name)
            if (prefix_mode)
                return index(name, base_filter) == 1

            return index(name, base_filter) > 0
        }

        function human_size(bytes,   value, idx, units) {
            if (bytes == "" || bytes == empty_field_token || bytes !~ /^[0-9]+$/)
                return empty_field_token

            split("B KB MB GB TB", units, " ")
            value = bytes + 0
            idx = 1

            while (value >= 1024 && idx < 5) {
                value /= 1024
                idx += 1
            }

            if (idx == 1)
                return sprintf("%d %s", value, units[idx])

            return sprintf("%.1f %s", value, units[idx])
        }

        function matches_record(installed_flag,   category, haystack, origin_parts) {
            split($4, origin_parts, "/")
            category = tolower($4 == empty_field_token ? "" : origin_parts[1])

            if (category_filter != "" && category != category_filter)
                return 0

            if (installed_filter == "true" && !installed_flag)
                return 0

            if (installed_filter == "false" && installed_flag)
                return 0

            if (!matches_package_name($1, package_filter))
                return 0

            if (text_filter == "")
                return 1

            haystack = tolower($1 " " $3 " " $4)
            return index(haystack, text_filter) > 0
        }

        BEGIN {
            matched = 0
            loaded = 0
            has_next = 0
        }

        FNR == NR {
            installed_versions[$1] = $2
            next
        }

        {
            installed_flag = (($1 in installed_versions) ? 1 : 0)
            installed_version = installed_flag ? installed_versions[$1] : empty_field_token
            update_value = 0

            if (installed_flag && installed_version != empty_field_token && installed_version != $2)
                update_value = 1

            if (!matches_record(installed_flag))
                next

            if (matched < offset) {
                matched += 1
                next
            }

            if (loaded < limit) {
                size_text = human_size($6)
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\n",
                    $1, $2, $3, $4, $5, $6, $7, $8,
                    installed_flag, update_value, installed_version, size_text
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
    ' "$installed_file" "$source_file" >"$target_file"
}

parse_query_filters() {
    query_text="$1"

    printf '%s\n' "$query_text" | awk '
        BEGIN {
            category = ""
            package_filter = ""
            installed = ""
            text = ""
            waiting_for_category = 0
            waiting_for_package = 0
            waiting_for_installed = 0
        }

        {
            for (i = 1; i <= NF; i += 1) {
                token = $i

                if (waiting_for_category) {
                    category = token
                    waiting_for_category = 0
                    continue
                }

                if (waiting_for_package) {
                    package_filter = token
                    waiting_for_package = 0
                    continue
                }

                if (waiting_for_installed) {
                    installed = token
                    waiting_for_installed = 0
                    continue
                }

                if (token ~ /^category:/) {
                    category_value = substr(token, 10)
                    if (category_value != "")
                        category = category_value
                    else
                        waiting_for_category = 1
                    continue
                }

                if (token ~ /^package:/ || token ~ /^name:/) {
                    package_value = token
                    sub(/^package:/, "", package_value)
                    sub(/^name:/, "", package_value)
                    if (package_value != "")
                        package_filter = package_value
                    else
                        waiting_for_package = 1
                    continue
                }

                if (token ~ /^installed:/) {
                    installed_value = substr(token, 11)
                    if (installed_value != "")
                        installed = installed_value
                    else
                        waiting_for_installed = 1
                    continue
                }

                if (text != "")
                    text = text " "
                text = text token
            }
        }

        END {
            printf "category=%s\n", category
            printf "package=%s\n", package_filter
            printf "installed=%s\n", installed
            printf "text=%s\n", text
        }
    '
}

normalize_installed_filter() {
    case "${1:-}" in
        true|1|yes|on)
            printf 'true\n'
            ;;
        false|0|no|off)
            printf 'false\n'
            ;;
        *)
            printf '\n'
            ;;
    esac
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

dependency_blob_for_package() {
    mode="$1"
    package_name="$2"

    case "$mode" in
        installed)
            dependency_output="$(pkg query '%dn' "$package_name" 2>/dev/null || true)"
            ;;
        remote)
            dependency_output="$(pkg rquery '%dn' "$package_name" 2>/dev/null || true)"
            ;;
        *)
            dependency_output=""
            ;;
    esac

    first_entry=1
    printf '%s\n' "$dependency_output" | while IFS= read -r dependency_name; do
        dependency_name="$(printf '%s\n' "$dependency_name" | awk '
            {
                gsub(/\r/, "", $0)
                sub(/^[[:space:]]+/, "", $0)
                sub(/[[:space:]]+$/, "", $0)
                print
            }
        ')"

        [ -n "$dependency_name" ] || continue

        dependency_installed=0
        if pkg info -q -e "$dependency_name" 2>/dev/null; then
            dependency_installed=1
        fi

        if [ "$first_entry" -eq 0 ]; then
            printf '|'
        fi

        printf '%s~%s' "$dependency_name" "$dependency_installed"
        first_entry=0
    done

    printf '\n'
}

attach_dependencies_to_page() {
    input_file="$1"
    output_file="$2"

    : >"$output_file"

    while IFS='	' read -r name version comment origin website size_bytes description license installed update_available installed_version size_text; do
        [ -n "$name" ] || continue

        dependency_mode="remote"
        if [ "${installed:-0}" = "1" ]; then
            dependency_mode="installed"
        fi

        dependency_blob="$(dependency_blob_for_package "$dependency_mode" "$name")"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$name" \
            "$version" \
            "$comment" \
            "$origin" \
            "$website" \
            "$size_bytes" \
            "$description" \
            "$license" \
            "$installed" \
            "$update_available" \
            "$installed_version" \
            "$size_text" \
            "$dependency_blob" >>"$output_file"
    done <"$input_file"
}

enrich_browse_page() {
    page_file="$1"
    installed_file="$2"
    output_file="$3"
    : >"$output_file"

    while IFS='	' read -r name version comment origin website size_bytes description license; do
        [ -n "$name" ] || continue

        installed=0
        installed_version=""
        update_value=0

        installed_version="$(awk -F '	' -v pkg_name="$name" '
            $1 == pkg_name {
                print $2
                exit
            }
        ' "$installed_file")"

        if [ -z "$installed_version" ]; then
            installed_version="$(pkg query '%v' "$name" 2>/dev/null || true)"
        fi

        if [ -n "$installed_version" ]; then
            installed=1
        elif pkg info -q -e "$name" 2>/dev/null; then
            installed=1
        fi

        if [ "$installed" -eq 1 ] && [ -n "$installed_version" ] && [ "$installed_version" != "$version" ]; then
            comparison="$(pkg version -t "$installed_version" "$version" 2>/dev/null || printf '=')"
            if [ "$comparison" = "<" ]; then
                update_value=1
            fi
        fi

        size_text="$(human_size_value "$size_bytes")"
        comment="$(encode_empty_field "$comment")"
        origin="$(encode_empty_field "$origin")"
        website="$(encode_empty_field "$website")"
        description="$(encode_empty_field "$description")"
        license="$(encode_empty_field "$license")"
        installed_version="$(encode_empty_field "$installed_version")"
        size_text="$(encode_empty_field "$size_text")"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$name" \
            "$version" \
            "$comment" \
            "$origin" \
            "$website" \
            "$size_bytes" \
            "$description" \
            "$license" \
            "$installed" \
            "$update_value" \
            "$installed_version" \
            "$size_text" >>"$output_file"
    done <"$page_file"
}

enrich_installed_page() {
    page_file="$1"
    query_format="$2"
    field_sep="$3"
    output_file="$4"

    : >"$output_file"

    while IFS='	' read -r name installed_version comment origin website size_bytes description license; do
        [ -n "$name" ] || continue

        remote_record="$(query_remote_record "$name" "$query_format" "$field_sep" || true)"

        version="$installed_version"
        merged_comment="$comment"
        merged_origin="$origin"
        merged_website="$website"
        merged_size="$size_bytes"
        merged_description="$description"
        merged_license="$license"
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
                merged_license="$(printf '%s\n' "$remote_record" | awk -F '	' 'NR == 1 { print $8 }')"

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

        merged_comment="$(encode_empty_field "$merged_comment")"
        merged_origin="$(encode_empty_field "$merged_origin")"
        merged_website="$(encode_empty_field "$merged_website")"
        merged_description="$(encode_empty_field "$merged_description")"
        merged_license="$(encode_empty_field "$merged_license")"
        installed_version="$(encode_empty_field "$installed_version")"
        size_text="$(encode_empty_field "$size_text")"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\t%s\n' \
            "$name" \
            "$version" \
            "$merged_comment" \
            "$merged_origin" \
            "$merged_website" \
            "$merged_size" \
            "$merged_description" \
            "$merged_license" \
            "$update_available" \
            "$installed_version" \
            "$size_text" >>"$output_file"
    done <"$page_file"
}

build_updates_page() {
    installed_file="$1"
    query_format="$2"
    field_sep="$3"
    text_filter="$4"
    category_filter="$5"
    package_filter="$6"
    offset="$7"
    limit="$8"
    page_file="$9"
    meta_file="${10}"

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

        if [ -n "$text_filter" ] || [ -n "$category_filter" ] || [ -n "$package_filter" ]; then
            if ! printf '%s\n' "$remote_record" | awk -F '	' -v text_filter="$text_filter" -v category_filter="$category_filter" -v package_filter="$package_filter" '
                function matches_package_name(name, filter, prefix_mode, base_filter) {
                    if (filter == "")
                        return 1

                    prefix_mode = (filter ~ /\*$/)
                    base_filter = prefix_mode ? substr(filter, 1, length(filter) - 1) : filter
                    if (base_filter == "")
                        return 1

                    name = tolower(name)
                    if (prefix_mode)
                        return index(name, base_filter) == 1

                    return index(name, base_filter) > 0
                }

                BEGIN { found = 0 }
                {
                    split($4, origin_parts, "/")
                    category = tolower(origin_parts[1])

                    if (category_filter != "" && category != category_filter)
                        next

                    if (!matches_package_name($1, package_filter))
                        next

                    if (text_filter == "") {
                        found = 1
                        next
                    }

                    haystack = tolower($1 " " $3 " " $4)
                    if (index(haystack, text_filter) > 0)
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

            installed_version="$(encode_empty_field "$installed_version")"
            size_text="$(encode_empty_field "$size_text")"

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
        -v installed_size_label="$installed_size_label" \
        -v empty_field_token="$empty_field_token" '
        function escape_json(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            gsub(/\t/, " ", value)
            gsub(/\r/, " ", value)
            gsub(/\n/, " ", value)
            return value
        }

        function decode_field(value) {
            if (value == empty_field_token)
                return ""
            return value
        }

        function quote(value) {
            return "\"" escape_json(value) "\""
        }

        function emit_dependency_array(blob,   count, dep_fields, i, installed_flag, parts, first_dep) {
            printf "["
            if (blob != "") {
                count = split(blob, parts, /\|/)
                first_dep = 1
                for (i = 1; i <= count; i += 1) {
                    if (parts[i] == "")
                        continue

                    if (!first_dep)
                        printf ","

                    split(parts[i], dep_fields, /~/)
                    installed_flag = (dep_fields[2] == "1" ? "true" : "false")
                    printf "{\"name\":%s,\"installed\":%s}", quote(dep_fields[1]), installed_flag
                    first_dep = 0
                }
            }
            printf "]"
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

            package_comment = decode_field($3)
            if (package_comment == "")
                package_comment = "No package summary available."

            package_description = decode_field($7)
            if (package_description == "")
                package_description = package_comment

            package_license = decode_field($8)
            if (package_license == "")
                package_license = "Unknown"

            printf "{"
            printf "\"name\":%s,", quote(decode_field($1))
            printf "\"version\":%s,", quote(decode_field($2))
            printf "\"installed_version\":%s,", quote(decode_field($11))
            printf "\"installed\":%s,", ($9 == "1" ? "true" : "false")
            printf "\"update_available\":%s,", ($10 == "1" ? "true" : "false")
            printf "\"repo\":%s,", quote(repo_name(decode_field($4)))
            printf "\"origin\":%s,", quote(decode_field($4))
            printf "\"category\":%s,", quote(category_name(decode_field($4)))
            printf "\"comment\":%s,", quote(package_comment)
            printf "\"description\":%s,", quote(package_description)
            printf "\"website\":%s,", quote(decode_field($5))
            printf "\"license\":%s,", quote(package_license)
            printf "\"size\":%s,", quote(decode_field($12))
            printf "\"size_bytes\":%s,", (decode_field($6) == "" ? "0" : decode_field($6))
            printf "\"dependencies\":"
            emit_dependency_array(decode_field($13))
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
    query_format="$(printf '%%n%s%%v%s%%c%s%%o%s%%w%s%%sb%s%%L' \
        "$field_sep" \
        "$field_sep" \
        "$field_sep" \
        "$field_sep" \
        "$field_sep" \
        "$field_sep")"
    query_lc="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"
    parsed_filters="$(parse_query_filters "$query_lc")"
    text_filter="$(printf '%s\n' "$parsed_filters" | awk -F '=' '$1 == "text" { print substr($0, 6) }')"
    category_filter="$(printf '%s\n' "$parsed_filters" | awk -F '=' '$1 == "category" { print substr($0, 10) }')"
    package_filter="$(printf '%s\n' "$parsed_filters" | awk -F '=' '$1 == "package" { print substr($0, 9) }')"
    installed_filter_raw="$(printf '%s\n' "$parsed_filters" | awk -F '=' '$1 == "installed" { print substr($0, 11) }')"
    installed_filter="$(normalize_installed_filter "$installed_filter_raw")"

    installed_tsv="$tmp_dir/installed.tsv"
    remote_tsv="$tmp_dir/remote.tsv"
    page_raw_tsv="$tmp_dir/page-raw.tsv"
    page_tsv="$tmp_dir/page.tsv"
    page_with_dependencies_tsv="$tmp_dir/page-with-dependencies.tsv"
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
            if ! pkg rquery -a "$query_format" 2>"$tmp_dir/remote.err" | normalize_records "$field_sep" >"$remote_tsv"; then
                remote_error="$(tr '\n' ' ' <"$tmp_dir/remote.err" | trim_file)"
                error_json "Unable to query remote pkg metadata. ${remote_error}"
                exit 1
            fi

            collect_browse_page "$installed_tsv" "$remote_tsv" "$page_tsv" "$page_meta" "$text_filter" "$category_filter" "$package_filter" "$installed_filter" "$offset" "$page_size"
            ;;
        installed)
            if [ "$installed_filter" = "false" ]; then
                : >"$page_tsv"
                printf 'loaded=0\nhas_next=0\n' >"$page_meta"
            else
                collect_page_from_file "$installed_tsv" "$page_raw_tsv" "$page_meta" "$text_filter" "$category_filter" "$package_filter" "$offset" "$page_size"
                enrich_installed_page "$page_raw_tsv" "$query_format" "$field_sep" "$page_tsv"
            fi
            ;;
        updates)
            if [ "$installed_filter" = "false" ]; then
                : >"$page_tsv"
                printf 'loaded=0\nhas_next=0\n' >"$page_meta"
            else
                build_updates_page "$installed_tsv" "$query_format" "$field_sep" "$text_filter" "$category_filter" "$package_filter" "$offset" "$page_size" "$page_tsv" "$page_meta"
            fi
            ;;
    esac

    attach_dependencies_to_page "$page_tsv" "$page_with_dependencies_tsv"

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
        "$page_with_dependencies_tsv" \
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
