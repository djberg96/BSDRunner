#!/bin/sh

set -eu

session_name="${1:-BSDRunner}"
home_config="$HOME/.config"
launcher="$home_config/bsdrunner/scripts/bsdrunner-launch-hyprland.sh"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
session_log_dir="$state_home/bsdrunner"
session_log="$session_log_dir/session.log"

launch_logged() {
    old_umask="$(umask)"
    umask 077
    mkdir -p "$session_log_dir"
    chmod 700 "$session_log_dir"
    if [ -f "$session_log" ]; then
        mv -f "$session_log" "$session_log_dir/session.previous.log"
    fi
    : >"$session_log"
    chmod 600 "$session_log"
    umask "$old_umask"

    if [ "$session_name" = BSDRunner ] && [ -n "${BSDRUNNER_LOGIN_THEME:-}" ]; then
        case "$BSDRUNNER_LOGIN_THEME" in
            default|haas-bioroid|jinteki|nbn|weyland)
                BSDRUNNER_THEME_PREPARE_ONLY=1 sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" \
                    "$BSDRUNNER_LOGIN_THEME" >>"$session_log" 2>&1 || \
                    printf '%s\n' "Could not apply the selected login theme." >>"$session_log"
                ;;
        esac
    fi
    unset BSDRUNNER_LOGIN_THEME

    exec "$launcher" "$@" >>"$session_log" 2>&1
}

launch_hyprland() {
    # Let the normal BSDRunner autostart path decide whether to show the
    # welcome surface after a fresh desktop launch.
    touch "$home_config/bsdrunner/show-welcome-at-startup"
    launch_logged
}

launch_terminal() {
    terminal_config="$HOME/.config/hypr/bsdrunner-terminal.lua"

    if [ -x "$launcher" ] && command -v Hyprland >/dev/null 2>&1 && [ -f "$terminal_config" ]; then
        launch_logged "$terminal_config"
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
