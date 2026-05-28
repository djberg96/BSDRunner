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
