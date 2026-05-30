#!/bin/sh

set -eu

command -v rofi >/dev/null 2>&1 || exit 0

launcher="${ROFI_CMD:-rofi -dmenu}"
software_label="󰏖  Package Manager"
firewall_label="󰒃  Firewall"
firefox_label="󰈹  Firefox"

choice="$(
    printf '%s\n' \
        "$software_label" \
        "$firewall_label" \
        "$firefox_label" \
    | $launcher -i -p "Apps" -mesg "BSDRunner" 2>/dev/null
)"

[ -n "${choice:-}" ] || exit 0

case "$choice" in
    "$software_label")
        exec sh "$HOME/.config/bsdrunner/scripts/bsdrunner-software.sh"
        ;;
    "$firewall_label")
        exec sh "$HOME/.config/bsdrunner/scripts/bsdrunner-pf.sh"
        ;;
    "$firefox_label")
        exec firefox
        ;;
    *)
        exit 0
        ;;
esac
