#!/bin/sh

set -eu

config_path="$HOME/.config/hypr/bsdrunner-greeter.conf"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    printf '%s\n' "BSDRunner greeter session must be started from a text TTY, not from inside an existing graphical session." >&2
    printf '%s\n' "Switch to a console (for example Ctrl+Alt+F2), log in there, and run this script again." >&2
    exit 1
fi

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
