#!/bin/sh

set -eu

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
places_file="${BSDRUNNER_FILES_PLACES:-$HOME/.config/bsdrunner/files-places}"

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

path_hex() {
    LC_ALL=C printf '%s' "${1:-}" | od -An -tx1 | tr -d ' \n'
}

path_token() {
    printf '@hex:%s' "$(path_hex "${1:-}")"
}

hex_to_path() {
    hex="${1:-}"
    case "$hex" in
        ""|*[!0123456789abcdefABCDEF]*)
            return 1
            ;;
    esac
    [ $(( ${#hex} % 2 )) -eq 0 ] || return 1
    LC_ALL=C awk -v hex="$hex" '
        function hexval(ch) {
            return index("0123456789abcdef", tolower(ch)) - 1
        }
        function byteval(pair) {
            return hexval(substr(pair, 1, 1)) * 16 + hexval(substr(pair, 2, 1))
        }
        BEGIN {
            for (i = 1; i <= length(hex); i += 2)
                printf "%c", byteval(substr(hex, i, 2))
        }
    '
}

expand_path_ref() {
    raw="${1:-$HOME}"
    case "$raw" in
        @hex:*)
            hex_to_path "${raw#@hex:}"
            ;;
        *)
            expand_path "$raw"
            ;;
    esac
}

safe_bytes_label() {
    LC_ALL=C printf '%s' "${1:-}" | od -An -tx1 | tr -d ' \n' | awk '
        function hexval(ch) {
            return index("0123456789abcdef", tolower(ch)) - 1
        }
        function byteval(pair) {
            return hexval(substr(pair, 1, 1)) * 16 + hexval(substr(pair, 2, 1))
        }
        BEGIN {
            out = ""
        }
        {
            for (i = 1; i <= length($0); i += 2) {
                pair = substr($0, i, 2)
                value = byteval(pair)
                if (value >= 32 && value <= 126 && value != 92)
                    out = out sprintf("%c", value)
                else
                    out = out "\\x" tolower(pair)
            }
        }
        END {
            printf "%s", out
        }
    '
}

json_error() {
    message="${1:-Unable to load directory.}"
    printf '{"ok":false,"message":%s,"path":"","parent":"","entries":[]}\n' "$(json_string "$(safe_bytes_label "$message")")"
}

json_action() {
    ok="${1:-true}"
    message="${2:-Done.}"
    path="${3:-}"
    printf '{"ok":%s,"message":%s,"path":%s,"parent":"","entries":[]}\n' \
        "$ok" \
        "$(json_string "$(safe_bytes_label "$message")")" \
        "$(json_string "$(safe_bytes_label "$path")")"
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
    raw="$(expand_path_ref "${1:-$HOME}")"
    [ -n "$raw" ] || raw="$HOME"
    [ -d "$raw" ] || return 1
    (unset CDPATH; cd -P -- "$raw" 2>/dev/null && pwd -P)
}

clean_name() {
    name="${1:-}"
    case "$name" in
        ""|"."|".."|*/*)
            return 1
            ;;
    esac
    printf '%s\n' "$name"
}

unique_destination() {
    target_dir="$1"
    target_name="$2"
    destination="$target_dir/$target_name"
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
        printf '%s\n' "$destination"
        return 0
    fi

    suffix=1
    while :; do
        destination="$target_dir/$target_name.$suffix"
        if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
            printf '%s\n' "$destination"
            return 0
        fi
        suffix=$((suffix + 1))
    done
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
    display_name="$(safe_bytes_label "$name")"
    display_path="$(safe_bytes_label "$entry")"
    token="$(path_token "$entry")"
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

    printf '%s\t%s\t' "$sort_kind" "$(printf '%s' "$display_name" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
    printf '{"name":%s,' "$(json_string "$display_name")"
    printf '"display_name":%s,' "$(json_string "$display_name")"
    printf '"path":%s,' "$(json_string "$display_path")"
    printf '"display_path":%s,' "$(json_string "$display_path")"
    printf '"path_token":%s,' "$(json_string "$token")"
    printf '"kind":%s,' "$(json_string "$kind")"
    printf '"hidden":%s,' "$hidden"
    printf '"size_bytes":%s,' "$bytes"
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

canonical_path() {
    candidate="${1:-}"
    [ -d "$candidate" ] || return 1
    (unset CDPATH; cd -P -- "$candidate" 2>/dev/null && pwd -P)
}

shortcut_seen() {
    shortcut_path="$1"
    shortcut_real="$(canonical_path "$shortcut_path" 2>/dev/null || printf '%s\n' "$shortcut_path")"
    grep -F "\"real_path\":$(json_string "$shortcut_real")" "$shortcut_tmp" >/dev/null 2>&1
}

add_shortcut() {
    shortcut_label="$1"
    shortcut_path="$2"
    [ -d "$shortcut_path" ] || return 0
    shortcut_real="$(canonical_path "$shortcut_path" 2>/dev/null || printf '%s\n' "$shortcut_path")"
    shortcut_seen "$shortcut_path" && return 0
    printf '{"label":%s,"path":%s,"real_path":%s}\n' \
        "$(json_string "$shortcut_label")" \
        "$(json_string "$shortcut_path")" \
        "$(json_string "$shortcut_real")" >> "$shortcut_tmp"
}

add_media_shortcuts() {
    for media_root in \
        "/media" \
        "/mnt" \
        "/run/media/${USER:-}" \
        "/var/run/media/${USER:-}" \
        "/Volumes"
    do
        [ -d "$media_root" ] || continue
        for media_entry in "$media_root"/*; do
            [ -d "$media_entry" ] || continue
            [ "${media_entry##*/}" = "home" ] && [ -d "$HOME" ] && continue
            add_shortcut "${media_entry##*/} (${media_root##*/})" "$media_entry"
        done
    done
}

place_label() {
    place_path="${1:-}"
    if [ "$place_path" = "$HOME" ]; then
        printf 'Home'
    elif [ "$place_path" = "/" ]; then
        printf '/'
    else
        printf '%s' "${place_path##*/}"
    fi
}

add_custom_shortcuts() {
    [ -f "$places_file" ] || return 0
    while IFS= read -r custom_place || [ -n "$custom_place" ]; do
        [ -n "$custom_place" ] || continue
        custom_path="$(expand_path "$custom_place")"
        [ -d "$custom_path" ] || continue
        custom_real="$(canonical_path "$custom_path" 2>/dev/null || printf '%s\n' "$custom_path")"
        add_shortcut "$(place_label "$custom_real")" "$custom_real"
    done < "$places_file"
}

default_place_seen() {
    target_real="$1"
    for default_place in \
        "$HOME" \
        "$HOME/Desktop" \
        "$HOME/Downloads" \
        "$HOME/Documents" \
        "$HOME/Pictures"
    do
        [ -d "$default_place" ] || continue
        default_real="$(canonical_path "$default_place" 2>/dev/null || printf '%s\n' "$default_place")"
        [ "$target_real" = "$default_real" ] && return 0
    done
    return 1
}

custom_place_seen() {
    target_real="$1"
    [ -f "$places_file" ] || return 1
    while IFS= read -r custom_place || [ -n "$custom_place" ]; do
        [ -n "$custom_place" ] || continue
        custom_path="$(expand_path "$custom_place")"
        [ -d "$custom_path" ] || continue
        custom_real="$(canonical_path "$custom_path" 2>/dev/null || printf '%s\n' "$custom_path")"
        [ "$target_real" = "$custom_real" ] && return 0
    done < "$places_file"
    return 1
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

    add_shortcut "Home" "$HOME"
    add_shortcut "Desktop" "$HOME/Desktop"
    add_shortcut "Downloads" "$HOME/Downloads"
    add_shortcut "Documents" "$HOME/Documents"
    add_shortcut "Pictures" "$HOME/Pictures"
    add_custom_shortcuts
    add_media_shortcuts

    printf '{"ok":true,'
    printf '"message":%s,' "$(json_string "Loaded $(safe_bytes_label "$path")")"
    printf '"path":%s,' "$(json_string "$(safe_bytes_label "$path")")"
    printf '"path_token":%s,' "$(json_string "$(path_token "$path")")"
    printf '"parent":%s,' "$(json_string "$(safe_bytes_label "$parent")")"
    printf '"parent_token":%s,' "$(json_string "$(path_token "$parent")")"

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
    target="$(expand_path_ref "${1:-}")"
    if [ -z "$target" ] || { ! [ -e "$target" ] && ! [ -L "$target" ]; }; then
        json_error "Path does not exist: ${1:-}"
        exit 1
    fi

    if [ -d "$target" ]; then
        printf '{"ok":true,"message":%s,"path":%s,"path_token":%s,"parent":"","entries":[]}\n' \
            "$(json_string "Directory navigation is handled by BSDRunner Files.")" \
            "$(json_string "$(safe_bytes_label "$target")")" \
            "$(json_string "$(path_token "$target")")"
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

    printf '{"ok":true,"message":%s,"path":%s,"path_token":%s,"parent":"","entries":[]}\n' \
        "$(json_string "Opened $(safe_bytes_label "${target##*/}").")" \
        "$(json_string "$(safe_bytes_label "$target")")" \
        "$(json_string "$(path_token "$target")")"
}

create_folder() {
    parent="$(resolve_directory "${1:-$HOME}")" || {
        json_error "Parent is not a writable directory: ${1:-$HOME}"
        exit 1
    }
    [ -w "$parent" ] || {
        json_error "Directory is not writable: $parent"
        exit 1
    }

    name="$(clean_name "${2:-}")" || {
        json_error "Folder name cannot be empty or contain '/'."
        exit 1
    }
    target="$parent/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        json_error "A file or folder named '$name' already exists."
        exit 1
    fi

    mkdir "$target"
    json_action true "Created folder $name." "$target"
}

rename_path() {
    target="$(expand_path_ref "${1:-}")"
    if [ -z "$target" ] || { ! [ -e "$target" ] && ! [ -L "$target" ]; }; then
        json_error "Path does not exist: ${1:-}"
        exit 1
    fi
    [ "$target" != "/" ] || {
        json_error "Cannot rename root."
        exit 1
    }

    name="$(clean_name "${2:-}")" || {
        json_error "New name cannot be empty or contain '/'."
        exit 1
    }
    parent="$(dirname "$target")"
    destination="$parent/$name"
    if [ "$destination" = "$target" ]; then
        json_action true "Name unchanged." "$target"
        return 0
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        json_error "A file or folder named '$name' already exists."
        exit 1
    fi

    mv "$target" "$destination"
    json_action true "Renamed to $name." "$destination"
}

trash_path() {
    target="$(expand_path_ref "${1:-}")"
    if [ -z "$target" ] || { ! [ -e "$target" ] && ! [ -L "$target" ]; }; then
        json_error "Path does not exist: ${1:-}"
        exit 1
    fi
    [ "$target" != "/" ] || {
        json_error "Cannot trash root."
        exit 1
    }

    if command -v gio >/dev/null 2>&1; then
        if gio trash "$target" >/dev/null 2>&1; then
            json_action true "Moved ${target##*/} to trash." "$target"
            return 0
        fi
    fi

    trash_files="$HOME/.local/share/Trash/files"
    trash_info="$HOME/.local/share/Trash/info"
    mkdir -p "$trash_files" "$trash_info"

    base="${target##*/}"
    destination="$(unique_destination "$trash_files" "$base")"
    mv "$target" "$destination"
    info_name="${destination##*/}.trashinfo"
    {
        printf '[Trash Info]\n'
        printf 'Path=%s\n' "$target"
        date '+DeletionDate=%Y-%m-%dT%H:%M:%S'
    } > "$trash_info/$info_name"

    json_action true "Moved $base to trash." "$destination"
}

open_terminal() {
    target="$(resolve_directory "${1:-$HOME}")" || {
        json_error "Terminal path is not a directory: ${1:-$HOME}"
        exit 1
    }

    if command -v kitty >/dev/null 2>&1; then
        kitty --directory "$target" >/dev/null 2>&1 &
    elif command -v foot >/dev/null 2>&1; then
        foot --working-directory "$target" >/dev/null 2>&1 &
    elif command -v alacritty >/dev/null 2>&1; then
        alacritty --working-directory "$target" >/dev/null 2>&1 &
    else
        json_error "No supported terminal found."
        exit 1
    fi

    json_action true "Opened terminal in $target." "$target"
}

copy_path() {
    target="$(expand_path_ref "${1:-}")"
    if [ -z "$target" ] || { ! [ -e "$target" ] && ! [ -L "$target" ]; }; then
        json_error "Path does not exist: ${1:-}"
        exit 1
    fi

    if command -v wl-copy >/dev/null 2>&1; then
        if printf '%s' "$target" | wl-copy >/dev/null 2>&1; then
            json_action true "Copied path for ${target##*/}." "$target"
            return 0
        fi
        json_error "Unable to reach the Wayland clipboard."
        exit 1
    elif command -v pbcopy >/dev/null 2>&1; then
        if printf '%s' "$target" | pbcopy >/dev/null 2>&1; then
            json_action true "Copied path for ${target##*/}." "$target"
            return 0
        fi
        json_error "Unable to copy path with pbcopy."
        exit 1
    elif command -v xclip >/dev/null 2>&1; then
        if printf '%s' "$target" | xclip -selection clipboard >/dev/null 2>&1; then
            json_action true "Copied path for ${target##*/}." "$target"
            return 0
        fi
        json_error "Unable to copy path with xclip."
        exit 1
    else
        json_error "No clipboard helper found. Install wl-clipboard for wl-copy."
        exit 1
    fi
}

add_place() {
    target="$(resolve_directory "${1:-}")" || {
        json_error "Place is not a directory: ${1:-}"
        exit 1
    }
    target_real="$(canonical_path "$target" 2>/dev/null || printf '%s\n' "$target")"
    target_label="$(place_label "$target_real")"

    if default_place_seen "$target_real" || custom_place_seen "$target_real"; then
        json_action true "$target_label is already in Places." "$target_real"
        return 0
    fi

    mkdir -p "$(dirname "$places_file")"
    printf '%s\n' "$target_real" >> "$places_file"
    json_action true "Added $target_label to Places." "$target_real"
}

action="${1:-snapshot}"
case "$action" in
    snapshot)
        snapshot "${2:-$HOME}"
        ;;
    open)
        open_path "${2:-}"
        ;;
    mkdir)
        create_folder "${2:-$HOME}" "${3:-}"
        ;;
    rename)
        rename_path "${2:-}" "${3:-}"
        ;;
    trash)
        trash_path "${2:-}"
        ;;
    terminal)
        open_terminal "${2:-$HOME}"
        ;;
    copy-path)
        copy_path "${2:-}"
        ;;
    add-place)
        add_place "${2:-}"
        ;;
    *)
        json_error "Unknown files backend action: $action"
        exit 1
        ;;
esac
