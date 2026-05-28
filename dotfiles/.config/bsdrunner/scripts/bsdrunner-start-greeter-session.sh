#!/bin/sh

set -eu

config_path="$HOME/.config/hypr/bsdrunner-greeter.conf"

command -v Hyprland >/dev/null 2>&1 || {
    printf '%s\n' "Hyprland is required for the BSDRunner greeter session." >&2
    exit 1
}

[ -f "$config_path" ] || {
    printf '%s\n' "Greeter Hyprland config is missing: $config_path" >&2
    exit 1
}

if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session Hyprland --config "$config_path"
fi

exec Hyprland --config "$config_path"
