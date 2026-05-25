#!/bin/sh

set -eu

action="${1:-snapshot}"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

error_json() {
    message="$1"
    printf '{"ok":false,"message":"%s","packages":[],"summary":{"total":0,"installed":0,"updates":0}}\n' \
        "$(json_escape "$message")"
}

normalize_records() {
    field_sep="$1"
    record_sep="$2"

    awk -v RS="$record_sep" -v FS="$field_sep" '
        function clean(value) {
            gsub(/\r/, "", value)
            gsub(/\n+/, " ", value)
            gsub(/\t+/, " ", value)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            gsub(/[[:space:]][[:space:]]+/, " ", value)
            return value
        }

        NF {
            for (i = 1; i <= 7; i += 1)
                $i = clean($i)

            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7
        }
    '
}

trim_file() {
    sed 's/[[:space:]][[:space:]]*/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

snapshot() {
    command -v pkg >/dev/null 2>&1 || {
        error_json "pkg is not installed or is not in PATH."
        exit 1
    }

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-software.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    field_sep="$(printf '\037')"
    record_sep="$(printf '\036')"
    query_format="%n${field_sep}%v${field_sep}%c${field_sep}%o${field_sep}%w${field_sep}%s${field_sep}%e${record_sep}"

    remote_tsv="$tmp_dir/remote.tsv"
    installed_tsv="$tmp_dir/installed.tsv"
    updates_txt="$tmp_dir/updates.txt"

    if ! pkg rquery -a "$query_format" 2>"$tmp_dir/remote.err" | normalize_records "$field_sep" "$record_sep" >"$remote_tsv"; then
        remote_error="$(tr '\n' ' ' <"$tmp_dir/remote.err" | trim_file)"
        error_json "Unable to query remote pkg metadata. ${remote_error}"
        exit 1
    fi

    if ! pkg query -a "$query_format" 2>"$tmp_dir/installed.err" | normalize_records "$field_sep" "$record_sep" >"$installed_tsv"; then
        installed_error="$(tr '\n' ' ' <"$tmp_dir/installed.err" | trim_file)"
        error_json "Unable to query installed pkg metadata. ${installed_error}"
        exit 1
    fi

    : >"$updates_txt"

    while IFS='	' read -r name installed_version _rest; do
        [ -n "$name" ] || continue

        remote_version="$(
            awk -F '	' -v package_name="$name" '$1 == package_name { print $2; exit }' "$remote_tsv"
        )"

        [ -n "$remote_version" ] || continue

        comparison="$(pkg version -t "$installed_version" "$remote_version" 2>/dev/null || printf '=')"

        if [ "$comparison" = "<" ]; then
            printf '%s\n' "$name" >>"$updates_txt"
        fi
    done <"$installed_tsv"

    generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    awk -F '	' -v generated_at="$generated_at" '
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

        function emit_package(name, version, comment, origin, website, size_bytes, description, installed, update_available, installed_version, first_record) {
            package_size_text = human_size(size_bytes)
            package_comment = comment
            if (package_comment == "")
                package_comment = "No package summary available."

            package_description = description
            if (package_description == "")
                package_description = package_comment

            package_installed_text = "false"
            if (installed)
                package_installed_text = "true"

            package_update_text = "false"
            if (update_available)
                package_update_text = "true"

            package_size_bytes_text = size_bytes
            if (package_size_bytes_text == "")
                package_size_bytes_text = "0"

            if (!first_record)
                printf ","

            printf "{"
            printf "\"name\":%s,", quote(name)
            printf "\"version\":%s,", quote(version)
            printf "\"installed_version\":%s,", quote(installed_version)
            printf "\"installed\":%s,", package_installed_text
            printf "\"update_available\":%s,", package_update_text
            printf "\"repo\":%s,", quote(repo_name(origin))
            printf "\"origin\":%s,", quote(origin)
            printf "\"category\":%s,", quote(category_name(origin))
            printf "\"comment\":%s,", quote(package_comment)
            printf "\"description\":%s,", quote(package_description)
            printf "\"website\":%s,", quote(website)
            printf "\"license\":\"\","
            printf "\"size\":%s,", quote(package_size_text)
            printf "\"size_bytes\":%s,", package_size_bytes_text
            printf "\"dependencies\":[]"
            printf "}"
        }

        FNR == NR {
            remote_count += 1
            remote_order[remote_count] = $1
            remote_seen[$1] = 1
            remote_version[$1] = $2
            remote_comment[$1] = $3
            remote_origin[$1] = $4
            remote_website[$1] = $5
            remote_size[$1] = $6
            remote_description[$1] = $7
            next
        }

        FILENAME == ARGV[2] {
            installed_seen[$1] = 1
            installed_version[$1] = $2
            installed_comment[$1] = $3
            installed_origin[$1] = $4
            installed_website[$1] = $5
            installed_size[$1] = $6
            installed_description[$1] = $7

            if (!remote_seen[$1]) {
                installed_only_count += 1
                installed_only_order[installed_only_count] = $1
            }

            next
        }

        {
            updates[$1] = 1
        }

        END {
            total = 0
            installed_total = 0
            updates_total = 0
            first_record = 1

            printf "{"
            printf "\"ok\":true,"
            printf "\"message\":%s,", quote("Loaded package metadata from pkg.")
            printf "\"generated_at\":%s,", quote(generated_at)
            printf "\"packages\":["

            for (i = 1; i <= remote_count; i += 1) {
                name = remote_order[i]
                installed = 0
                if (name in installed_seen)
                    installed = 1

                update_available = 0
                if (name in updates)
                    update_available = 1

                current_installed_version = ""
                if (installed)
                    current_installed_version = installed_version[name]

                if (installed)
                    installed_total += 1
                if (update_available)
                    updates_total += 1

                emit_package(name, remote_version[name], remote_comment[name], remote_origin[name], remote_website[name], remote_size[name], remote_description[name], installed, update_available, current_installed_version, first_record)

                first_record = 0
                total += 1
            }

            for (i = 1; i <= installed_only_count; i += 1) {
                name = installed_only_order[i]
                installed_total += 1

                emit_package(name, installed_version[name], installed_comment[name], installed_origin[name], installed_website[name], installed_size[name], installed_description[name], 1, 0, installed_version[name], first_record)

                first_record = 0
                total += 1
            }

            printf "],"
            printf "\"summary\":{\"total\":%d,\"installed\":%d,\"updates\":%d}", total, installed_total, updates_total
            printf "}\n"
        }
    ' "$remote_tsv" "$installed_tsv" "$updates_txt"
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
