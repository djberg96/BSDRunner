#!/bin/sh

set -eu

config_path="$HOME/.config/hypr/bsdrunner-greeter.conf"
launcher="$HOME/.config/bsdrunner/scripts/bsdrunner-launch-hyprland.sh"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    printf '%s\n' "BSDRunner greeter session must be started from a text TTY, not from inside an existing graphical session." >&2
    printf '%s\n' "Switch to a console (for example Ctrl+Alt+F2), log in there, and run this script again." >&2
    exit 1
fi

command -v Hyprland >/dev/null 2>&1 || {
    printf '%s\n' "Hyprland is required for the BSDRunner greeter session." >&2
    exit 1
}

[ -x "$launcher" ] || {
    printf '%s\n' "Hyprland launcher helper is missing: $launcher" >&2
    exit 1
}

[ -f "$config_path" ] || {
    printf '%s\n' "Greeter Hyprland config is missing: $config_path" >&2
    exit 1
}

exec "$launcher" "$config_path"
