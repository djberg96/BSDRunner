#!/bin/sh

set -eu

launcher="${ROFI_CMD:-rofi -dmenu}"
current_theme="default"
theme_file="$HOME/.config/bsdrunner/current-theme"

if [ -f "$theme_file" ]; then
    current_theme="$(tr -d '\n' < "$theme_file")"
fi

choice="$(
    printf '%s\n' \
        "default" \
        "jinteki" \
        "haas-bioroid" \
        "nbn" \
        "weyland" \
    | rofi -dmenu -i -p "Theme" -mesg "Current: $current_theme"
)"

[ -n "${choice:-}" ] || exit 0

exec sh "$HOME/.config/bsdrunner/scripts/bsdrunner-apply-theme.sh" "$choice"
