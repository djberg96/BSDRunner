#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

config_name="bsdrunner-apps"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
[ -d "$runtime_dir" ] || runtime_dir="/tmp"
pid_file="$runtime_dir/bsdrunner-apps-menu.pid"
log_file="/tmp/bsdrunner-apps-menu.log"

menu_process_is_running() {
    menu_pid="$1"

    case "$menu_pid" in
        ''|*[!0-9]*) return 1 ;;
    esac

    kill -0 "$menu_pid" 2>/dev/null || return 1

    # kill -0 also succeeds for zombies. Treat them as stopped so a defunct
    # Quickshell process cannot consume the first click after the menu closes.
    menu_state="$(ps -p "$menu_pid" -o state= 2>/dev/null | tr -d '[:space:]' || true)"
    case "$menu_state" in
        ''|Z*) return 1 ;;
    esac

    # A stale pid file must never make us signal an unrelated reused PID.
    menu_args="$(ps -p "$menu_pid" -o args= 2>/dev/null || true)"
    case "$menu_args" in
        *"qs -c $config_name"*|*"quickshell -c $config_name"*) return 0 ;;
        *) return 1 ;;
    esac
}

if [ -r "$pid_file" ]; then
    menu_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if menu_process_is_running "$menu_pid"; then
        kill "$menu_pid" 2>/dev/null || true
        rm -f "$pid_file"
        exit 0
    fi
    rm -f "$pid_file"
fi

if command -v qs >/dev/null 2>&1; then
    quickshell_cmd="qs"
elif command -v quickshell >/dev/null 2>&1; then
    quickshell_cmd="quickshell"
else
    printf '%s\n' "Unable to find qs or quickshell in PATH." > "$log_file"
    exit 0
fi

printf '%s\n' "$$" > "$pid_file"

# Waybar already runs click commands asynchronously. Keeping Quickshell in the
# foreground lets Waybar reap it instead of leaving it orphaned under the
# session manager, where it can remain as a zombie.
exec "$quickshell_cmd" -c "$config_name" > "$log_file" 2>&1
