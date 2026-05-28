#!/bin/sh

set -eu

launch_terminal() {
    if command -v kitty >/dev/null 2>&1; then
        kitty
        return
    fi

    if command -v foot >/dev/null 2>&1; then
        foot
        return
    fi

    if command -v xterm >/dev/null 2>&1; then
        xterm
        return
    fi

    printf '%s\n' "No supported terminal emulator was found for the BSDRunner Terminal session." >&2
    exit 1
}

launch_terminal

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exit >/dev/null 2>&1 || true
fi
