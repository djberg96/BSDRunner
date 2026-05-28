#!/bin/sh

set -eu

config_path="${1:-}"
user_id="$(id -u)"
runtime_dir=""

ensure_runtime_dir() {
    candidate="${XDG_RUNTIME_DIR:-}"

    if [ -n "$candidate" ] && [ -d "$candidate" ] && [ -O "$candidate" ] && [ -w "$candidate" ]; then
        runtime_dir="$candidate"
        export XDG_RUNTIME_DIR="$runtime_dir"
        return 0
    fi

    candidate="/var/run/user/$user_id"
    if [ -d "$candidate" ] && [ -O "$candidate" ] && [ -w "$candidate" ]; then
        runtime_dir="$candidate"
        export XDG_RUNTIME_DIR="$runtime_dir"
        return 0
    fi

    runtime_dir="/tmp/${USER}-runtime"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
    export XDG_RUNTIME_DIR="$runtime_dir"
}

ensure_runtime_dir

unset DBUS_SESSION_BUS_ADDRESS

export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"

if command -v start-hyprland >/dev/null 2>&1; then
    if [ -n "$config_path" ]; then
        exec start-hyprland --config "$config_path"
    fi

    exec start-hyprland
fi

if command -v dbus-run-session >/dev/null 2>&1; then
    if [ -n "$config_path" ]; then
        exec dbus-run-session Hyprland --config "$config_path"
    fi

    exec dbus-run-session Hyprland
fi

if [ -n "$config_path" ]; then
    exec Hyprland --config "$config_path"
fi

exec Hyprland
