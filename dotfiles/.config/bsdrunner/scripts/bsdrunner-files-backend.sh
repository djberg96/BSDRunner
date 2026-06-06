#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

json_string() {
    printf '%s' "${1:-}" | awk '
        BEGIN { printf "\"" }
        {
            if (NR > 1)
                printf "\\n"
            for (i = 1; i <= length($0); i += 1) {
                c = substr($0, i, 1)
                if (c == "\\")
                    printf "\\\\"
                else if (c == "\"")
                    printf "\\\""
                else if (c == "\b")
                    printf "\\b"
                else if (c == "\f")
                    printf "\\f"
                else if (c == "\r")
                    printf "\\r"
                else if (c == "\t")
                    printf "\\t"
                else
                    printf "%s", c
            }
        }
        END { printf "\"" }
    '
}

json_error() {
    message="${1:-Unable to load directory.}"
    printf '{"ok":false,"message":%s,"path":"","parent":"","entries":[]}\n' "$(json_string "$message")"
}

expand_path() {
    raw="${1:-$HOME}"
    case "$raw" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${raw#~/}"
            ;;
        *)
            printf '%s\n' "$raw"
            ;;
    esac
}

resolve_directory() {
    raw="$(expand_path "${1:-$HOME}")"
    [ -n "$raw" ] || raw="$HOME"
    [ -d "$raw" ] || return 1
    (unset CDPATH; cd -P -- "$raw" 2>/dev/null && pwd -P)
}

stat_size() {
    stat -f '%z' "$1" 2>/dev/null || stat -c '%s' "$1" 2>/dev/null || printf '0'
}

stat_mtime() {
    stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$1" 2>/dev/null \
        || stat -c '%y' "$1" 2>/dev/null | awk '{ print $1 " " substr($2, 1, 5) }' \
        || printf ''
}

size_label() {
    bytes="${1:-0}"
    awk -v bytes="$bytes" '
        BEGIN {
            value = bytes + 0
            split("B KiB MiB GiB TiB", units, " ")
            unit = 1
            while (value >= 1024 && unit < 5) {
                value = value / 1024
                unit += 1
            }
            if (unit == 1)
                printf "%d B", value
            else
                printf "%.1f %s", value, units[unit]
        }
    '
}

entry_kind() {
    if [ -L "$1" ]; then
        printf 'symlink'
    elif [ -d "$1" ]; then
        printf 'directory'
    elif [ -f "$1" ]; then
        printf 'file'
    else
        printf 'other'
    fi
}

entry_json_line() {
    entry="$1"
    name="${entry##*/}"
    kind="$(entry_kind "$entry")"
    hidden=false
    case "$name" in
        .*) hidden=true ;;
    esac

    if [ "$kind" = "directory" ]; then
        bytes=0
        label="Folder"
    else
        bytes="$(stat_size "$entry")"
        label="$(size_label "$bytes")"
    fi

    readable=false
    writable=false
    executable=false
    [ -r "$entry" ] && readable=true
    [ -w "$entry" ] && writable=true
    [ -x "$entry" ] && executable=true

    sort_kind=1
    [ "$kind" = "directory" ] && sort_kind=0

    printf '%s\t%s\t' "$sort_kind" "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    printf '{"name":%s,' "$(json_string "$name")"
    printf '"path":%s,' "$(json_string "$entry")"
    printf '"kind":%s,' "$(json_string "$kind")"
    printf '"hidden":%s,' "$hidden"
    printf '"size_label":%s,' "$(json_string "$label")"
    printf '"mtime_label":%s,' "$(json_string "$(stat_mtime "$entry")")"
    printf '"readable":%s,' "$readable"
    printf '"writable":%s,' "$writable"
    printf '"executable":%s}' "$executable"
    printf '\n'
}

shortcut_json_line() {
    shortcut_label="$1"
    shortcut_path="$2"
    [ -d "$shortcut_path" ] || return 0
    printf '{"label":%s,"path":%s}\n' "$(json_string "$shortcut_label")" "$(json_string "$shortcut_path")"
}

snapshot() {
    path="$(resolve_directory "${1:-$HOME}")" || {
        json_error "Path is not a readable directory: ${1:-$HOME}"
        exit 1
    }

    if ! [ -r "$path" ]; then
        json_error "Directory is not readable: $path"
        exit 1
    fi

    parent="$(dirname "$path")"
    [ "$path" = "/" ] && parent="/"

    entry_tmp="${TMPDIR:-/tmp}/bsdrunner-files-entries.$$"
    shortcut_tmp="${TMPDIR:-/tmp}/bsdrunner-files-shortcuts.$$"
    trap 'rm -f "$entry_tmp" "$shortcut_tmp"' EXIT HUP INT TERM
    : > "$entry_tmp"
    : > "$shortcut_tmp"

    if [ "$path" = "/" ]; then
        for entry in /* /.[!.]* /..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            entry_json_line "$entry" >> "$entry_tmp"
        done
    else
        for entry in "$path"/* "$path"/.[!.]* "$path"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            entry_json_line "$entry" >> "$entry_tmp"
        done
    fi

    shortcut_json_line "Home" "$HOME" >> "$shortcut_tmp"
    shortcut_json_line "Desktop" "$HOME/Desktop" >> "$shortcut_tmp"
    shortcut_json_line "Downloads" "$HOME/Downloads" >> "$shortcut_tmp"
    shortcut_json_line "Documents" "$HOME/Documents" >> "$shortcut_tmp"
    shortcut_json_line "Pictures" "$HOME/Pictures" >> "$shortcut_tmp"
    shortcut_json_line "Root" "/" >> "$shortcut_tmp"
    shortcut_json_line "Media" "/media" >> "$shortcut_tmp"
    shortcut_json_line "Mounts" "/mnt" >> "$shortcut_tmp"
    shortcut_json_line "Run Media" "/run/media/${USER:-}" >> "$shortcut_tmp"

    printf '{"ok":true,'
    printf '"message":%s,' "$(json_string "Loaded $path")"
    printf '"path":%s,' "$(json_string "$path")"
    printf '"parent":%s,' "$(json_string "$parent")"

    printf '"shortcuts":['
    first=true
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '%s' "$line"
    done < "$shortcut_tmp"
    printf '],'

    printf '"entries":['
    first=true
    sort "$entry_tmp" | while IFS='	' read -r _sort_kind _sort_name line; do
        [ -n "$line" ] || continue
        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '%s' "$line"
    done
    printf ']}\n'
}

open_path() {
    target="$(expand_path "${1:-}")"
    if [ -z "$target" ] || { ! [ -e "$target" ] && ! [ -L "$target" ]; }; then
        json_error "Path does not exist: ${1:-}"
        exit 1
    fi

    if [ -d "$target" ]; then
        printf '{"ok":true,"message":%s,"path":%s,"parent":"","entries":[]}\n' \
            "$(json_string "Directory navigation is handled by BSDRunner Files.")" \
            "$(json_string "$target")"
        return 0
    fi

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$target" >/dev/null 2>&1 &
    elif command -v gio >/dev/null 2>&1; then
        gio open "$target" >/dev/null 2>&1 &
    else
        json_error "No desktop opener found. Install xdg-utils for xdg-open."
        exit 1
    fi

    printf '{"ok":true,"message":%s,"path":%s,"parent":"","entries":[]}\n' \
        "$(json_string "Opened ${target##*/}.")" \
        "$(json_string "$target")"
}

action="${1:-snapshot}"
case "$action" in
    snapshot)
        snapshot "${2:-$HOME}"
        ;;
    open)
        open_path "${2:-}"
        ;;
    *)
        json_error "Unknown files backend action: $action"
        exit 1
        ;;
esac
