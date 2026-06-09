#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

action="${1:-}"
package_name="${2:-}"

json_escape() {
    printf '%s' "$1" | awk '
        BEGIN {
            first = 1
        }

        {
            gsub(/\\/, "\\\\")
            gsub(/"/, "\\\"")
            gsub(/\r/, "")

            if (!first)
                printf "\\n"

            printf "%s", $0
            first = 0
        }
    '
}

emit_json() {
    ok="$1"
    message="$2"
    details="${3:-}"
    log_path="${4:-}"
    printf '{"ok":%s,"action":"%s","package":"%s","message":"%s","details":"%s","log_path":"%s"}\n' \
        "$ok" \
        "$(json_escape "$action")" \
        "$(json_escape "$package_name")" \
        "$(json_escape "$message")" \
        "$(json_escape "$details")" \
        "$(json_escape "$log_path")"
}

log_file_for_action() {
    state_dir="${HOME}/.local/state/bsdrunner/pkg-actions"
    timestamp="$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$state_dir"
    printf '%s/%s-%s-%s.log\n' "$state_dir" "$timestamp" "$action" "$package_name"
}

write_log_file() {
    target="$1"
    stdout_file="$2"
    stderr_file="$3"
    preview_stdout_file="${4:-}"
    preview_stderr_file="${5:-}"

    {
        printf 'BSDRunner package action log\n'
        printf 'action: %s\n' "$action"
        printf 'package: %s\n' "$package_name"
        printf 'timestamp: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        if [ -n "$preview_stdout_file" ] || [ -n "$preview_stderr_file" ]; then
            printf '\n[pkg dry-run stdout]\n'
            cat "$preview_stdout_file" 2>/dev/null || true
            printf '\n[pkg dry-run stderr]\n'
            cat "$preview_stderr_file" 2>/dev/null || true
        fi
        printf '\n[stdout]\n'
        cat "$stdout_file" 2>/dev/null || true
        printf '\n[stderr]\n'
        cat "$stderr_file" 2>/dev/null || true
    } >"$target"
}

package_name_is_valid() {
    case "$1" in
        '')
            return 1
            ;;
        *[!A-Za-z0-9._+-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

installed_version() {
    pkg query '%v' "$package_name" 2>/dev/null || true
}

package_is_installed() {
    pkg info -q -e "$package_name" 2>/dev/null
}

verify_expected_state() {
    current_version="$(installed_version)"

    case "$action" in
        install|reinstall|upgrade)
            package_is_installed
            ;;
        remove)
            ! package_is_installed
            ;;
        *)
            return 1
            ;;
    esac
}

planned_removed_packages() {
    awk '
        /^Installed packages to be REMOVED:/ {
            in_removed = 1
            next
        }

        in_removed && /^[[:space:]]*$/ {
            in_removed = 0
            next
        }

        in_removed && /^[[:space:]]+[A-Za-z0-9._+-]+:/ {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            sub(/:.*/, "", line)
            if (line != "")
                print line
        }
    ' "$1" | sort -u
}

protected_package() {
    case "$1" in
        dbus|dolphin|foot|hyprland|hyprlauncher|kitty|librsvg2|librsvg2-rust|mate-polkit|polkit|quickshell|rofi|rofi-wayland|seatd|swww|waybar|wlogout|xdg-desktop-portal|xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland|xdg-utils)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

protected_removed_packages() {
    while IFS= read -r removed_package; do
        [ -n "$removed_package" ] || continue
        if protected_package "$removed_package"; then
            printf '%s\n' "$removed_package"
        fi
    done
}

run_preview() {
    stdout_file="$1"
    stderr_file="$2"

    case "$action" in
        install|upgrade)
            pkg install -n -y -- "$package_name" >"$stdout_file" 2>"$stderr_file"
            ;;
        reinstall)
            pkg install -n -f -y -- "$package_name" >"$stdout_file" 2>"$stderr_file"
            ;;
        remove)
            pkg delete -n -y -- "$package_name" >"$stdout_file" 2>"$stderr_file"
            ;;
        *)
            return 1
            ;;
    esac
}

validate_preview() {
    preview_stdout_file="$1"
    preview_stderr_file="$2"
    log_file="$3"

    if ! run_preview "$preview_stdout_file" "$preview_stderr_file"; then
        write_log_file "$log_file" /dev/null /dev/null "$preview_stdout_file" "$preview_stderr_file"
        emit_json false "pkg could not plan $action for $package_name." "See log: $log_file" "$log_file"
        return 1
    fi

    planned_removals="$(planned_removed_packages "$preview_stdout_file")"
    case "$action" in
        install|reinstall|upgrade)
            if [ -n "$planned_removals" ]; then
                write_log_file "$log_file" /dev/null /dev/null "$preview_stdout_file" "$preview_stderr_file"
                details="$(printf 'BSDRunner blocked this action because pkg planned to remove installed packages:\n%s\n\nUse the terminal if you intentionally want to resolve this conflict manually.' "$planned_removals")"
                emit_json false "Blocked $action for $package_name because pkg planned removals." "$details" "$log_file"
                return 1
            fi
            ;;
        remove)
            protected_removals="$(printf '%s\n' "$planned_removals" | protected_removed_packages)"
            if [ -n "$protected_removals" ]; then
                write_log_file "$log_file" /dev/null /dev/null "$preview_stdout_file" "$preview_stderr_file"
                details="$(printf 'BSDRunner blocked this removal because pkg planned to remove protected desktop packages:\n%s\n\nUse the terminal if you intentionally want to change the desktop stack.' "$protected_removals")"
                emit_json false "Blocked removal because protected BSDRunner desktop packages would be removed." "$details" "$log_file"
                return 1
            fi
            ;;
    esac
}

run_action() {
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-software-action.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    preview_stdout_file="$tmp_dir/preview-stdout.log"
    preview_stderr_file="$tmp_dir/preview-stderr.log"
    stdout_file="$tmp_dir/stdout.log"
    stderr_file="$tmp_dir/stderr.log"
    log_file="$(log_file_for_action)"

    validate_preview "$preview_stdout_file" "$preview_stderr_file" "$log_file" || return 1

    if "$@" >"$stdout_file" 2>"$stderr_file"; then
        write_log_file "$log_file" "$stdout_file" "$stderr_file" "$preview_stdout_file" "$preview_stderr_file"

        if ! verify_expected_state; then
            current_version="$(installed_version)"
            case "$action" in
                install|reinstall|upgrade)
                    verification_message="pkg finished, but $package_name does not appear to be installed afterward."
                    ;;
                remove)
                    verification_message="pkg finished, but $package_name still appears to be installed afterward."
                    ;;
                *)
                    verification_message="Package state verification failed for $package_name."
                    ;;
            esac

            if [ -n "$current_version" ]; then
                verification_message="$verification_message Installed version after action: $current_version."
            fi

            emit_json false "$verification_message" "See log: $log_file" "$log_file"
            return 1
        fi

        emit_json true "$success_message" "" "$log_file"
        return 0
    fi

    write_log_file "$log_file" "$stdout_file" "$stderr_file" "$preview_stdout_file" "$preview_stderr_file"

    emit_json false "$failure_message" "See log: $log_file" "$log_file"
    return 1
}

if ! command -v pkg >/dev/null 2>&1; then
    emit_json false "pkg is not installed or is not in PATH." "" ""
    exit 1
fi

if ! command -v mdo >/dev/null 2>&1; then
    emit_json false "mdo is not installed or is not in PATH." "" ""
    exit 1
fi

case "$action" in
    install|reinstall|upgrade|remove)
        if ! package_name_is_valid "$package_name"; then
            emit_json false "Invalid package name: $package_name" "" ""
            exit 1
        fi
        if protected_package "$package_name"; then
            details="$(printf '%s is protected because BSDRunner depends on it for the desktop session or core UI. The Software Manager will not install, reinstall, upgrade, or remove protected packages.\n\nUse the terminal if you intentionally want to change the desktop stack.' "$package_name")"
            emit_json false "Blocked $action for protected BSDRunner package $package_name." "$details" ""
            exit 1
        fi
        ;;
    *)
        emit_json false "Unknown package action: $action" "" ""
        exit 1
        ;;
esac

case "$action" in
    install)
        success_message="Installed $package_name."
        failure_message="Unable to install $package_name."
        run_action \
            mdo -- pkg install -y -- "$package_name"
        ;;
    reinstall)
        success_message="Reinstalled $package_name."
        failure_message="Unable to reinstall $package_name."
        run_action \
            mdo -- pkg install -f -y -- "$package_name"
        ;;
    upgrade)
        success_message="Upgrade request completed for $package_name."
        failure_message="Unable to upgrade $package_name."
        run_action \
            mdo -- pkg install -y -- "$package_name"
        ;;
    remove)
        success_message="Removed $package_name."
        failure_message="Unable to remove $package_name."
        run_action \
            mdo -- pkg delete -y -- "$package_name"
        ;;
esac
