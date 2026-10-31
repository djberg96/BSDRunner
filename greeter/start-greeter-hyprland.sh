#!/bin/sh

set -eu

bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
config_path="$bundle_dir/hyprland.lua"
temporary_runtime=""
log_dir="${BSDRUNNER_GREETER_LOG_DIR:-}"

cleanup() {
    if [ -n "$temporary_runtime" ] && [ -d "$temporary_runtime" ]; then
        rm -rf -- "$temporary_runtime"
    fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "${BSDRUNNER_GREETER_DBUS_CHILD:-0}" != 1 ]; then
    # The minimal greetd-greeter PAM service does not run pam_xdg on FreeBSD,
    # so provide a private runtime directory for Wayland and D-Bus. Prefer one
    # supplied by PAM when it is available.
    if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -d "$XDG_RUNTIME_DIR" ] || [ -L "$XDG_RUNTIME_DIR" ] || [ ! -O "$XDG_RUNTIME_DIR" ]; then
        old_umask="$(umask)"
        umask 077
        # Keep this path short. FreeBSD's sockaddr_un limit is small enough
        # that nested Hyprland IPC names overflow with a descriptive prefix.
        temporary_runtime="$(mktemp -d /tmp/bsdg.XXXXXX)"
        umask "$old_umask"
        XDG_RUNTIME_DIR="$temporary_runtime"
        export XDG_RUNTIME_DIR
    fi

    cache_dir="$XDG_RUNTIME_DIR/bsdrunner-greeter/cache"
    mkdir -p "$cache_dir"
    chmod 700 "$XDG_RUNTIME_DIR/bsdrunner-greeter" "$cache_dir"
    XDG_CACHE_HOME="$cache_dir"
    export XDG_CACHE_HOME

    old_umask="$(umask)"
    umask 077
    log_parent="${BSDRUNNER_GREETER_LOG_ROOT:-/var/tmp}"
    if [ ! -d "$log_parent" ] || [ ! -w "$log_parent" ]; then
        log_parent="${TMPDIR:-/tmp}"
    fi
    log_dir="$(mktemp -d "$log_parent/bsdrunner-greeter-log.XXXXXX")"
    umask "$old_umask"
    BSDRUNNER_GREETER_LOG_DIR="$log_dir"
    export BSDRUNNER_GREETER_LOG_DIR

    {
        printf 'XDG_RUNTIME_DIR=%s\n' "$XDG_RUNTIME_DIR"
        printf 'greeter log directory=%s\n' "$log_dir"
    } >"$log_dir/launcher.log"

    # Own the D-Bus session here so all of its output is captured alongside
    # the greeter logs instead of briefly appearing on the login VT.
    BSDRUNNER_GREETER_DBUS_CHILD=1
    export BSDRUNNER_GREETER_DBUS_CHILD
    set +e
    if command -v dbus-run-session >/dev/null 2>&1; then
        dbus-run-session "$0" >>"$log_dir/session.log" 2>&1
        status="$?"
    else
        "$0" >>"$log_dir/session.log" 2>&1
        status="$?"
    fi
    set -e

    printf 'greeter session exit status=%s\n' "$status" >>"$log_dir/launcher.log"
    exit "$status"
fi

[ -n "$log_dir" ] && [ -d "$log_dir" ] || {
    printf '%s\n' "BSDRunner greeter child started without a log directory." >&2
    exit 1
}

if command -v start-hyprland >/dev/null 2>&1; then
    set +e
    start-hyprland -- --config "$config_path" >>"$log_dir/hyprland.log" 2>&1
    status="$?"
    set -e
else
    set +e
    Hyprland --config "$config_path" >>"$log_dir/hyprland.log" 2>&1
    status="$?"
    set -e
fi

printf 'Hyprland exit status=%s\n' "$status" >>"$log_dir/launcher.log"
exit "$status"
