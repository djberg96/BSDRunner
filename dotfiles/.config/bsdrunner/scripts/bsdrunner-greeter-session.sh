#!/bin/sh

set -eu

session_name="${1:-BSDRunner}"
home_config="$HOME/.config"

launch_hyprland() {
    # Let the normal BSDRunner autostart path decide whether to show the
    # welcome surface after a fresh desktop launch.
    touch "$home_config/bsdrunner/show-welcome-at-startup"

    if command -v dbus-run-session >/dev/null 2>&1; then
        exec dbus-run-session Hyprland
    fi

    exec Hyprland
}

launch_terminal() {
    terminal_config="$HOME/.config/hypr/bsdrunner-terminal.conf"

    if command -v Hyprland >/dev/null 2>&1 && [ -f "$terminal_config" ]; then
        if command -v dbus-run-session >/dev/null 2>&1; then
            exec dbus-run-session Hyprland --config "$terminal_config"
        fi

        exec Hyprland --config "$terminal_config"
    fi

    exec "${SHELL:-/bin/sh}" -l
}

case "$session_name" in
    BSDRunner)
        launch_hyprland
        ;;
    Terminal)
        launch_terminal
        ;;
    *)
        printf '%s\n' "Unknown BSDRunner session: $session_name" >&2
        exit 1
        ;;
esac
