#!/bin/sh

set -eu

action="${1:-}"
package_name="${2:-}"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; :a;N;$!ba;s/\n/\\n/g'
}

emit_json() {
    ok="$1"
    message="$2"
    details="${3:-}"
    printf '{"ok":%s,"action":"%s","package":"%s","message":"%s","details":"%s"}\n' \
        "$ok" \
        "$(json_escape "$action")" \
        "$(json_escape "$package_name")" \
        "$(json_escape "$message")" \
        "$(json_escape "$details")"
}

progress() {
    printf '%s\n' "$1"
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

run_action() {
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-software-action.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    stdout_file="$tmp_dir/stdout.log"
    stderr_file="$tmp_dir/stderr.log"

    progress "$1"
    shift

    if "$@" >"$stdout_file" 2>"$stderr_file"; then
        if [ -s "$stdout_file" ]; then
            cat "$stdout_file"
        fi

        details="$(cat "$stdout_file" "$stderr_file" 2>/dev/null || true)"
        emit_json true "$success_message" "$details"
        return 0
    fi

    if [ -s "$stdout_file" ]; then
        cat "$stdout_file"
    fi

    details="$(cat "$stdout_file" "$stderr_file" 2>/dev/null || true)"
    if [ -n "$details" ]; then
        printf '%s\n' "$details" >&2
    fi

    emit_json false "$failure_message" "$details"
    return 1
}

if ! command -v pkg >/dev/null 2>&1; then
    emit_json false "pkg is not installed or is not in PATH." ""
    exit 1
fi

if ! command -v mdo >/dev/null 2>&1; then
    emit_json false "mdo is not installed or is not in PATH." ""
    exit 1
fi

case "$action" in
    install|reinstall|upgrade|remove)
        if ! package_name_is_valid "$package_name"; then
            emit_json false "Invalid package name: $package_name" ""
            exit 1
        fi
        ;;
    *)
        emit_json false "Unknown package action: $action" ""
        exit 1
        ;;
esac

case "$action" in
    install)
        success_message="Installed $package_name."
        failure_message="Unable to install $package_name."
        run_action \
            "Installing $package_name..." \
            mdo -- pkg install -y -- "$package_name"
        ;;
    reinstall)
        success_message="Reinstalled $package_name."
        failure_message="Unable to reinstall $package_name."
        run_action \
            "Reinstalling $package_name..." \
            mdo -- pkg install -f -y -- "$package_name"
        ;;
    upgrade)
        success_message="Upgrade request completed for $package_name."
        failure_message="Unable to upgrade $package_name."
        run_action \
            "Upgrading $package_name..." \
            mdo -- pkg install -y -- "$package_name"
        ;;
    remove)
        success_message="Removed $package_name."
        failure_message="Unable to remove $package_name."
        run_action \
            "Removing $package_name..." \
            mdo -- pkg delete -y -- "$package_name"
        ;;
esac
