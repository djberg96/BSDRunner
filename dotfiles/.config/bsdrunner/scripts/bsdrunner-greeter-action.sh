#!/bin/sh

set -eu

action="${1:-}"
session="${2:-}"
home_config="$HOME/.config"

run_with_privilege() {
    if command -v mdo >/dev/null 2>&1; then
        exec mdo "$@"
    fi

    if command -v doas >/dev/null 2>&1; then
        exec doas "$@"
    fi

    if [ "$(id -u)" -eq 0 ]; then
        exec "$@"
    fi

    printf '%s\n' "No privilege helper was found for $1. Configure mdo or doas first." >&2
    exit 1
}

launch_preview() {
    case "$1" in
        BSDRunner)
            sh "$home_config/bsdrunner/scripts/bsdrunner-welcome.sh" >/dev/null 2>&1 &
            printf '%s\n' "Launched BSDRunner preview."
            ;;
        Terminal)
            kitty >/dev/null 2>&1 &
            printf '%s\n' "Launched Terminal preview."
            ;;
        *)
            printf '%s\n' "Unknown session: $1" >&2
            exit 1
            ;;
    esac
}

case "$action" in
    login)
        launch_preview "$session"
        ;;
    shutdown)
        run_with_privilege shutdown -p now
        ;;
    restart)
        run_with_privilege shutdown -r now
        ;;
    *)
        printf '%s\n' "Unknown greeter action: $action" >&2
        exit 1
        ;;
esac
